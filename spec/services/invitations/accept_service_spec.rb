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

    context "with valid invitation and parameters" do
      it "returns a success response" do
        response = described_class.new(invitation: invitation, params: valid_params).call

        expect(response).to be_success
      end

      it "creates a user with the invitation email" do
        # Ensure the invitation is created first (with its librarian association)
        invitation

        expect {
          described_class.new(invitation: invitation, params: valid_params).call
        }.to change(User, :count).by(1)

        user = User.find_by(email: "invited@example.com")
        expect(user.email).to eq("invited@example.com")
        expect(user.name).to eq("New Librarian")
        expect(user.role).to eq("librarian")
      end

      it "marks the invitation as accepted" do
        described_class.new(invitation: invitation, params: valid_params).call

        invitation.reload
        expect(invitation).to be_accepted
      end

      it "includes success message in meta" do
        response = described_class.new(invitation: invitation, params: valid_params).call

        expect(response.meta[:message]).to eq("Account created successfully.")
      end
    end

    context "when invitation is expired (410 Gone)" do
      let(:expired_invitation) { create(:invitation, :expired, invited_by: librarian) }

      it "returns gone" do
        response = described_class.new(invitation: expired_invitation, params: valid_params).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:gone)
        expect(response.errors).to include("This invitation has expired.")
      end
    end

    context "when invitation is already accepted (410 Gone)" do
      let(:accepted_invitation) { create(:invitation, :accepted, invited_by: librarian) }

      it "returns gone" do
        response = described_class.new(invitation: accepted_invitation, params: valid_params).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:gone)
        expect(response.errors).to include("This invitation has already been used.")
      end
    end

    context "when user params are invalid" do
      it "returns error for missing name" do
        params = valid_params.merge(name: "")
        response = described_class.new(invitation: invitation, params: params).call

        expect(response).to be_failure
        expect(response.errors).to include("Name can't be blank")
      end

      it "returns error for short password" do
        params = valid_params.merge(password: "short", password_confirmation: "short")
        response = described_class.new(invitation: invitation, params: params).call

        expect(response).to be_failure
      end

      it "does not mark invitation as accepted when user creation fails" do
        params = valid_params.merge(name: "")
        described_class.new(invitation: invitation, params: params).call

        invitation.reload
        expect(invitation).not_to be_accepted
      end
    end
  end
end
