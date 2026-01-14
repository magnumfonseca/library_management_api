# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invitation, type: :model do
  let(:librarian) { create(:user, :librarian) }

  describe "validations" do
    subject { build(:invitation, invited_by: librarian) }

    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:role) }
    it { should validate_inclusion_of(:role).in_array(%w[librarian]) }

    it "generates token automatically" do
      invitation = build(:invitation, invited_by: librarian, token: nil)
      expect { invitation.valid? }.to change { invitation.token }.from(nil)
    end

    it "sets expires_at automatically" do
      invitation = build(:invitation, invited_by: librarian, expires_at: nil)
      expect { invitation.valid? }.to change { invitation.expires_at }.from(nil)
    end

    it "validates uniqueness of token" do
      existing = create(:invitation, invited_by: librarian)
      duplicate = build(:invitation, invited_by: librarian, token: existing.token)
      duplicate.valid?
      expect(duplicate.errors[:token]).to include("has already been taken")
    end
  end

  describe "associations" do
    it { should belong_to(:invited_by).class_name("User") }
  end

  describe "callbacks" do
    it "generates token before validation on create" do
      invitation = build(:invitation, invited_by: librarian, token: nil)
      invitation.valid?

      expect(invitation.token).to be_present
    end

    it "sets expiration before validation on create" do
      invitation = build(:invitation, invited_by: librarian, expires_at: nil)
      invitation.valid?

      expect(invitation.expires_at).to be_present
      expect(invitation.expires_at).to be > Time.current
    end
  end

  describe "scopes" do
    let!(:pending_invitation) { create(:invitation, invited_by: librarian) }
    let!(:expired_invitation) { create(:invitation, :expired, invited_by: librarian) }
    let!(:accepted_invitation) { create(:invitation, :accepted, invited_by: librarian) }

    describe ".pending" do
      it "returns only pending invitations" do
        expect(described_class.pending).to include(pending_invitation)
        expect(described_class.pending).not_to include(expired_invitation, accepted_invitation)
      end
    end

    describe ".expired" do
      it "returns only expired invitations" do
        expect(described_class.expired).to include(expired_invitation)
        expect(described_class.expired).not_to include(pending_invitation, accepted_invitation)
      end
    end

    describe ".accepted" do
      it "returns only accepted invitations" do
        expect(described_class.accepted).to include(accepted_invitation)
        expect(described_class.accepted).not_to include(pending_invitation, expired_invitation)
      end
    end
  end

  describe "#pending?" do
    it "returns true for pending invitation" do
      invitation = create(:invitation, invited_by: librarian)
      expect(invitation).to be_pending
    end

    it "returns false for expired invitation" do
      invitation = create(:invitation, :expired, invited_by: librarian)
      expect(invitation).not_to be_pending
    end

    it "returns false for accepted invitation" do
      invitation = create(:invitation, :accepted, invited_by: librarian)
      expect(invitation).not_to be_pending
    end
  end

  describe "#accept!" do
    it "marks invitation as accepted" do
      invitation = create(:invitation, invited_by: librarian)

      expect { invitation.accept! }.to change { invitation.accepted_at }.from(nil)
    end

    it "raises error if already accepted" do
      invitation = create(:invitation, :accepted, invited_by: librarian)

      expect { invitation.accept! }.to raise_error("Invitation already accepted")
    end

    it "raises error if expired" do
      invitation = create(:invitation, :expired, invited_by: librarian)

      expect { invitation.accept! }.to raise_error("Invitation has expired")
    end
  end
end
