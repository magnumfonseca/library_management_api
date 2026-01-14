# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:password) }
    it { should validate_length_of(:password).is_at_least(6) }
  end

  describe "roles" do
    it "defines member and librarian roles" do
      expect(User.roles).to eq({ "librarian"=>"librarian", "member"=>"member" })
    end

    it "defaults to member role" do
      user = User.new
      expect(user.role).to eq("member")
    end

    it "can be set to librarian" do
      user = build(:user, :librarian)
      expect(user.librarian?).to be true
    end

    it "can be set to member" do
      user = build(:user, :member)
      expect(user.member?).to be true
    end
  end

  describe "Devise modules" do
    it "includes database_authenticatable" do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it "includes registerable" do
      expect(User.devise_modules).to include(:registerable)
    end

    it "includes validatable" do
      expect(User.devise_modules).to include(:validatable)
    end

    it "includes jwt_authenticatable" do
      expect(User.devise_modules).to include(:jwt_authenticatable)
    end
  end

  describe "JWT" do
    describe "#jwt_payload" do
      it "returns a hash with user role" do
        user = build(:user, :librarian)
        expect(user.jwt_payload).to include("role" => "librarian")
      end
    end

    describe "#revoke_jwt" do
      it "regenerates the jti to invalidate existing tokens" do
        user = create(:user)
        original_jti = user.jti

        user.revoke_jwt

        expect(user.reload.jti).not_to eq(original_jti)
      end

      it "persists the new jti to the database" do
        user = create(:user)

        expect { user.revoke_jwt }.to change { user.reload.jti }
      end
    end
  end

  describe "business logic methods" do
    describe "#can_borrow_book?" do
      it "returns true if user is a member and has no active borrowing for the book" do
        user = create(:user, :member)
        book = create(:book)

        expect(user.can_borrow_book?(book)).to be true
      end

      it "returns false if user is not a member" do
        user = create(:user, :librarian)
        book = create(:book)

        expect(user.can_borrow_book?(book)).to be false
      end

      it "returns false if user has an active borrowing for the book" do
        user = create(:user, :member)
        book = create(:book)
        create(:borrowing, user: user, book: book, returned_at: nil)

        expect(user.can_borrow_book?(book)).to be false
      end
    end

    describe "#has_active_borrowing_for?" do
      it "returns true if user has an active borrowing for the book" do
        user = create(:user)
        book = create(:book)
        create(:borrowing, user: user, book: book, returned_at: nil)

        expect(user.has_active_borrowing_for?(book)).to be true
      end

      it "returns false if user does not have an active borrowing for the book" do
        user = create(:user)
        book = create(:book)

        expect(user.has_active_borrowing_for?(book)).to be false
      end
    end

    describe "#overdue_borrowings" do
      it "returns only overdue borrowings for the user" do
        user = create(:user)
        overdue_borrowing = create(:borrowing, user: user, due_date: 2.days.ago, returned_at: nil)
        on_time_borrowing = create(:borrowing, user: user, due_date: 2.days.from_now, returned_at: nil)

        result = user.overdue_borrowings

        expect(result).to include(overdue_borrowing)
        expect(result).not_to include(on_time_borrowing)
      end
    end

    describe "#active_borrowings_count" do
      it "returns the count of active borrowings for the user" do
        user = create(:user)
        create_list(:borrowing, 3, user: user, returned_at: nil)
        create_list(:borrowing, 2, user: user, returned_at: Time.current)

        expect(user.active_borrowings_count).to eq(3)
      end
    end
  end
end
