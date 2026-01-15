# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invitations::DeleteService do
  let(:librarian) { create(:user, :librarian) }
  let(:invitation) { create(:invitation, invited_by: librarian) }

  describe "#call" do
    context "with valid pending invitation" do
      it "returns a success response" do
        response = described_class.new(invitation: invitation).call

        expect(response).to be_success
      end

      it "destroys the invitation" do
        invitation # ensure it exists

        expect {
          described_class.new(invitation: invitation).call
        }.to change(Invitation, :count).by(-1)
      end

      it "includes success message in meta" do
        response = described_class.new(invitation: invitation).call

        expect(response.meta[:message]).to eq("Invitation cancelled successfully.")
      end
    end

    context "when invitation is nil" do
      it "returns failure response" do
        response = described_class.new(invitation: nil).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:not_found)
        expect(response.errors).to include("Invitation not found.")
      end
    end

    context "when invitation is already accepted" do
      let(:accepted_invitation) { create(:invitation, :accepted, invited_by: librarian) }

      it "returns failure response" do
        response = described_class.new(invitation: accepted_invitation).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:unprocessable_content)
        expect(response.errors).to include("Cannot cancel an accepted invitation.")
      end

      it "does not destroy the invitation" do
        accepted_invitation # ensure it exists

        expect {
          described_class.new(invitation: accepted_invitation).call
        }.not_to change(Invitation, :count)
      end
    end

    context "when invitation is expired" do
      let(:expired_invitation) { create(:invitation, :expired, invited_by: librarian) }

      it "returns failure response" do
        response = described_class.new(invitation: expired_invitation).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:unprocessable_content)
        expect(response.errors).to include("Cannot cancel an expired invitation.")
      end

      it "does not destroy the invitation" do
        expired_invitation # ensure it exists

        expect {
          described_class.new(invitation: expired_invitation).call
        }.not_to change(Invitation, :count)
      end
    end

    context "when destroy fails" do
      before do
        allow(invitation).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)
      end

      it "returns failure response" do
        response = described_class.new(invitation: invitation).call

        expect(response).to be_failure
        expect(response.http_status).to eq(:unprocessable_content)
        expect(response.errors).to include("Failed to cancel invitation.")
      end
    end
  end
end
