# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invitations::CreateService do
  let(:librarian) { create(:user, :librarian) }
  let(:member) { create(:user, :member) }

  describe "#call" do
    context "with valid parameters as librarian" do
      let(:params) { { email: "newlibrarian@example.com" } }

      it "returns a success response" do
        response = described_class.new(params: params, current_user: librarian).call

        expect(response).to be_success
      end

      it "creates an invitation" do
        expect {
          described_class.new(params: params, current_user: librarian).call
        }.to change(Invitation, :count).by(1)
      end

      it "sets the correct attributes" do
        response = described_class.new(params: params, current_user: librarian).call

        expect(response.data.email).to eq("newlibrarian@example.com")
        expect(response.data.role).to eq("librarian")
        expect(response.data.invited_by).to eq(librarian)
      end

      it "includes success message in meta" do
        response = described_class.new(params: params, current_user: librarian).call

        expect(response.meta[:message]).to eq("Invitation sent successfully.")
      end
    end



    context "when email is missing (400 Bad Request)" do
      it "returns bad request for empty email" do
        response = described_class.new(params: { email: "" }, current_user: librarian).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:bad_request)
        expect(response.errors).to include("Email is required.")
      end

      it "returns bad request for nil email" do
        response = described_class.new(params: { email: nil }, current_user: librarian).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:bad_request)
      end
    end

    context "when email already has an account (422 Unprocessable Entity)" do
      before { create(:user, email: "existing@example.com") }

      it "returns error" do
        response = described_class.new(
          params: { email: "existing@example.com" },
          current_user: librarian
        ).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:unprocessable_content)
        expect(response.errors).to include("A user with this email already exists.")
      end
    end

    context "when pending invitation exists (422 Unprocessable Entity)" do
      before { create(:invitation, email: "pending@example.com", invited_by: librarian) }

      it "returns error" do
        response = described_class.new(
          params: { email: "pending@example.com" },
          current_user: librarian
        ).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:unprocessable_content)
        expect(response.errors).to include("An invitation for this email is already pending.")
      end
    end
  end
end
