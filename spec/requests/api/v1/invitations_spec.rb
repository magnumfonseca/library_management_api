# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invitations API", type: :request do
  let(:librarian) { create(:user, :librarian) }
  let(:member) { create(:user, :member) }

  # Helper to generate JWT token for a user
  def jwt_token_for(user)
    Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
  end

  describe "DELETE /api/v1/invitations/:id" do
    let!(:invitation) { create(:invitation, invited_by: librarian) }

    context "when authenticated as a librarian" do
      let(:auth_headers) { { "Authorization" => "Bearer #{jwt_token_for(librarian)}" } }

      context "with a pending invitation" do
        it "successfully deletes the invitation" do
          expect {
            delete "/api/v1/invitations/#{invitation.id}", headers: auth_headers
          }.to change(Invitation, :count).by(-1)

          expect(response).to have_http_status(:no_content)
          expect(response.body).to be_empty
        end

        it "removes the invitation from the database" do
          delete "/api/v1/invitations/#{invitation.id}", headers: auth_headers

          expect(Invitation.find_by(id: invitation.id)).to be_nil
        end
      end

      context "with an accepted invitation" do
        let!(:invitation) { create(:invitation, :accepted, invited_by: librarian) }

        it "returns unprocessable entity status" do
          delete "/api/v1/invitations/#{invitation.id}", headers: auth_headers

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns an error message" do
          delete "/api/v1/invitations/#{invitation.id}", headers: auth_headers

          json = JSON.parse(response.body)
          expect(json["errors"]).to be_present
          expect(json["errors"].first["detail"]).to eq("Cannot cancel an accepted invitation.")
        end

        it "does not delete the invitation" do
          expect {
            delete "/api/v1/invitations/#{invitation.id}", headers: auth_headers
          }.not_to change(Invitation, :count)

          expect(Invitation.find_by(id: invitation.id)).to be_present
        end
      end

      context "with an expired invitation" do
        let!(:invitation) { create(:invitation, :expired, invited_by: librarian) }

        it "returns unprocessable entity status" do
          delete "/api/v1/invitations/#{invitation.id}", headers: auth_headers

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns an error message" do
          delete "/api/v1/invitations/#{invitation.id}", headers: auth_headers

          json = JSON.parse(response.body)
          expect(json["errors"]).to be_present
          expect(json["errors"].first["detail"]).to eq("Cannot cancel an expired invitation.")
        end

        it "does not delete the invitation" do
          expect {
            delete "/api/v1/invitations/#{invitation.id}", headers: auth_headers
          }.not_to change(Invitation, :count)

          expect(Invitation.find_by(id: invitation.id)).to be_present
        end
      end

      context "with a non-existent invitation" do
        it "returns not found status" do
          delete "/api/v1/invitations/999999", headers: auth_headers

          expect(response).to have_http_status(:not_found)
        end

        it "returns an error message" do
          delete "/api/v1/invitations/999999", headers: auth_headers

          json = JSON.parse(response.body)
          expect(json["errors"]).to be_present
          expect(json["errors"].first["status"]).to eq("404")
        end
      end
    end

    context "when authenticated as a member" do
      let(:auth_headers) { { "Authorization" => "Bearer #{jwt_token_for(member)}" } }

      it "returns forbidden status" do
        delete "/api/v1/invitations/#{invitation.id}", headers: auth_headers

        expect(response).to have_http_status(:forbidden)
      end

      it "does not delete the invitation" do
        expect {
          delete "/api/v1/invitations/#{invitation.id}", headers: auth_headers
        }.not_to change(Invitation, :count)

        expect(Invitation.find_by(id: invitation.id)).to be_present
      end
    end

    context "when not authenticated" do
      it "returns unauthorized status" do
        delete "/api/v1/invitations/#{invitation.id}"

        expect(response).to have_http_status(:unauthorized)
      end

      it "does not delete the invitation" do
        expect {
          delete "/api/v1/invitations/#{invitation.id}"
        }.not_to change(Invitation, :count)

        expect(Invitation.find_by(id: invitation.id)).to be_present
      end
    end
  end
end
