# frozen_string_literal: true

require "rails_helper"

RSpec.describe Borrowing, type: :model do
  describe "validations" do
    subject { build(:borrowing) }

    it { should belong_to(:user) }
    it { should belong_to(:book) }

    it "validates uniqueness of active borrowing per user and book" do
      user = create(:user)
      book = create(:book)
      create(:borrowing, user: user, book: book, returned_at: nil)

      duplicate_borrowing = build(:borrowing, user: user, book: book, returned_at: nil)
      expect(duplicate_borrowing).not_to be_valid
      expect(duplicate_borrowing.errors[:book_id]).to include("You already have an active borrowing for this book")
    end

    it "allows multiple borrowings for the same book if previous is returned" do
      user = create(:user)
      book = create(:book)
      create(:borrowing, user: user, book: book, returned_at: Time.current)

      new_borrowing = build(:borrowing, user: user, book: book, returned_at: nil)
      expect(new_borrowing).to be_valid
    end

    it "does not allow borrowing if book is not available" do
      book = create(:book, total_copies: 1)
      create(:borrowing, book: book, returned_at: nil) # Book is now fully borrowed

      borrowing = build(:borrowing, book: book)
      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:book]).to include("is not available for borrowing")
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active borrowings" do
        active_borrowing = create(:borrowing, returned_at: nil)
        returned_borrowing = create(:borrowing, returned_at: Time.current)

        result = Borrowing.active
        expect(result).to include(active_borrowing)
        expect(result).not_to include(returned_borrowing)
      end
    end

    describe ".returned" do
      it "returns only returned borrowings" do
        active_borrowing = create(:borrowing, returned_at: nil)
        returned_borrowing = create(:borrowing, returned_at: Time.current)
        result = Borrowing.returned
        expect(result).to include(returned_borrowing)
        expect(result).not_to include(active_borrowing)
      end
    end

    describe ".overdue" do
      it "returns only overdue borrowings" do
        overdue_borrowing = create(:borrowing, due_date: 2.days.ago, returned_at: nil)
        on_time_borrowing = create(:borrowing, due_date: 2.days.from_now, returned_at: nil)

        result = Borrowing.overdue
        expect(result).to include(overdue_borrowing)
        expect(result).not_to include(on_time_borrowing)
      end
    end

    describe ".due_today" do
      it "returns borrowings due today" do
        due_today_borrowing = create(:borrowing, due_date: Time.current.change(hour: 12), returned_at: nil)
        not_due_today_borrowing = create(:borrowing, due_date: 2.days.from_now, returned_at: nil)

        result = Borrowing.due_today
        expect(result).to include(due_today_borrowing)
        expect(result).not_to include(not_due_today_borrowing)
      end
    end

    describe ".due_soon" do
      it "returns borrowings due soon" do
        due_soon_borrowing = create(:borrowing, due_date: 3.days.from_now, returned_at: nil)
        not_due_soon_borrowing = create(:borrowing, due_date: 10.days.from_now, returned_at: nil)

        result = Borrowing.due_soon
        expect(result).to include(due_soon_borrowing)
        expect(result).not_to include(not_due_soon_borrowing)
      end
    end
  end

  describe "#mark_as_returned!" do
    it "marks an active borrowing as returned" do
      borrowing = create(:borrowing, returned_at: nil)

      borrowing.mark_as_returned!

      expect(borrowing.returned_at).not_to be_nil
      expect(borrowing).to be_returned
    end

    it "raises an error if trying to return an already returned borrowing" do
      borrowing = create(:borrowing, returned_at: Time.current)

      expect { borrowing.mark_as_returned! }.to raise_error(StandardError, "Already returned")
    end
  end
end
