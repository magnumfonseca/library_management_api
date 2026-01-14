# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invitations::AcceptService do
  let(:librarian) { create(:user, :librarian) }
  let(:invitation) { create(:invitation, email: "invited@example.com", invited_by: librarian) }

  describe "#call" do
    let(:valid_params) do
      {
        name: "New Librarian",
        password: "password123",
        password_confirmation: "password123"
      }
    end

    context "with valid token and parameters" do
      it "returns a success response" do
        response = described_class.new(token: invitation.token, params: valid_params).call

        expect(response).to be_success
      end

      it "creates a user with the invitation email" do
        # Ensure the invitation is created first (with its librarian association)
        invitation

        expect {
          described_class.new(token: invitation.token, params: valid_params).call
        }.to change(User, :count).by(1)

        user = User.find_by(email: "invited@example.com")
        expect(user.email).to eq("invited@example.com")
        expect(user.name).to eq("New Librarian")
        expect(user.role).to eq("librarian")
      end

      it "marks the invitation as accepted" do
        described_class.new(token: invitation.token, params: valid_params).call

        invitation.reload
        expect(invitation).to be_accepted
      end

      it "includes success message in meta" do
        response = described_class.new(token: invitation.token, params: valid_params).call

        expect(response.meta[:message]).to eq("Account created successfully.")
      end
    end

    context "when token is missing (400 Bad Request)" do
      it "returns bad request for empty token" do
        response = described_class.new(token: "", params: valid_params).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:bad_request)
        expect(response.errors).to include("Invitation token is required.")
      end

      it "returns bad request for nil token" do
        response = described_class.new(token: nil, params: valid_params).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:bad_request)
      end
    end

    context "when token is invalid (404 Not Found)" do
      it "returns not found" do
        response = described_class.new(token: "invalid_token", params: valid_params).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:not_found)
        expect(response.errors).to include("Invalid invitation token.")
      end
    end

    context "when invitation is expired (410 Gone)" do
      let(:expired_invitation) { create(:invitation, :expired, invited_by: librarian) }

      it "returns gone" do
        response = described_class.new(token: expired_invitation.token, params: valid_params).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:gone)
        expect(response.errors).to include("This invitation has expired.")
      end
    end

    context "when invitation is already accepted (410 Gone)" do
      let(:accepted_invitation) { create(:invitation, :accepted, invited_by: librarian) }

      it "returns gone" do
        response = described_class.new(token: accepted_invitation.token, params: valid_params).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:gone)
        expect(response.errors).to include("This invitation has already been used.")
      end
    end

    context "when user params are invalid" do
      it "returns error for missing name" do
        params = valid_params.merge(name: "")
        response = described_class.new(token: invitation.token, params: params).call

        expect(response).to be_failure
        expect(response.errors).to include("Name can't be blank")
      end

      it "returns error for short password" do
        params = valid_params.merge(password: "short", password_confirmation: "short")
        response = described_class.new(token: invitation.token, params: params).call

        expect(response).to be_failure
      end

      it "does not mark invitation as accepted when user creation fails" do
        params = valid_params.merge(name: "")
        described_class.new(token: invitation.token, params: params).call

        invitation.reload
        expect(invitation).not_to be_accepted
      end
    end
  end
end
