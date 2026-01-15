# frozen_string_literal: true

require "rails_helper"

RSpec.describe BorrowingPolicy do
  let(:member) { create(:user, :member) }
  let(:other_member) { create(:user, :member) }
  let(:librarian) { create(:user, :librarian) }
  let(:borrowing) { create(:borrowing, user: member) }

  describe "#index?" do
    it "allows members to view borrowings" do
      policy = described_class.new(member, Borrowing)

      expect(policy.index?).to be true
    end

    it "allows librarians to view borrowings" do
      policy = described_class.new(librarian, Borrowing)

      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    context "when user is a member" do
      it "allows member to view their own borrowing" do
        policy = described_class.new(member, borrowing)

        expect(policy.show?).to be true
      end

      it "denies member from viewing another user's borrowing" do
        policy = described_class.new(other_member, borrowing)

        expect(policy.show?).to be false
      end
    end

    context "when user is a librarian" do
      it "allows librarian to view any borrowing" do
        policy = described_class.new(librarian, borrowing)

        expect(policy.show?).to be true
      end
    end
  end

  describe "#create?" do
    it "allows members to create borrowings" do
      policy = described_class.new(member, Borrowing)

      expect(policy.create?).to be true
    end

    it "denies librarians from creating borrowings" do
      policy = described_class.new(librarian, Borrowing)

      expect(policy.create?).to be false
    end
  end

  describe "#return?" do
    it "allows librarians to return borrowings" do
      policy = described_class.new(librarian, borrowing)

      expect(policy.return?).to be true
    end

    it "denies members from returning borrowings" do
      policy = described_class.new(member, borrowing)

      expect(policy.return?).to be false
    end
  end

  describe "Scope" do
    let!(:member_borrowing) { create(:borrowing, user: member) }
    let!(:other_borrowing) { create(:borrowing, user: other_member) }

    describe "#resolve" do
      context "when user is a librarian" do
        it "returns all borrowings" do
          scope = described_class::Scope.new(librarian, Borrowing).resolve

          expect(scope).to include(member_borrowing, other_borrowing)
          expect(scope.count).to eq(2)
        end
      end

      context "when user is a member" do
        it "returns only the member's borrowings" do
          scope = described_class::Scope.new(member, Borrowing).resolve

          expect(scope).to include(member_borrowing)
          expect(scope).not_to include(other_borrowing)
          expect(scope.count).to eq(1)
        end
      end
    end
  end
end
