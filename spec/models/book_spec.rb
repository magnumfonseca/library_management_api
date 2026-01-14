# frozen_string_literal: true

require "rails_helper"

RSpec.describe Book, type: :model do
  describe "validations" do
    subject { build(:book) }

    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:author) }
    it { should validate_uniqueness_of(:isbn) }
    it { should validate_presence_of(:genre) }
    it { should validate_presence_of(:isbn) }
    it { should validate_numericality_of(:total_copies).is_greater_than(0) }
  end

  describe "scopes" do
    describe ".by_genre" do
      it "returns books of the specified genre" do
        fantasy_book = create(:book, genre: "Fantasy")
        mystery_book = create(:book, genre: "Mystery")

        result = Book.by_genre("Fantasy")
        expect(result).to include(fantasy_book)
        expect(result).not_to include(mystery_book)
      end
    end

    describe ".by_author" do
      it "returns books by the specified author" do
        rowling_book = create(:book, author: "J.K. Rowling")
        tolkien_book = create(:book, author: "J.R.R. Tolkien")

        result = Book.by_author("Rowling")
        expect(result).to include(rowling_book)
        expect(result).not_to include(tolkien_book)
      end
    end

    describe "#available_copies" do
      it "calculates available copies correctly" do
        book = create(:book, total_copies: 5)
        create_list(:borrowing, 2, book: book, returned_at: nil) # 2 active borrowings

        expect(book.available_copies).to eq(3)
      end
    end

    describe "#available?" do
      it "returns true if there are available copies" do
        book = create(:book, total_copies: 3)
        create_list(:borrowing, 2, book: book, returned_at: nil)

        expect(book.available?).to be true
      end

      it "returns false if there are no available copies" do
        book = create(:book, total_copies: 2)
        create_list(:borrowing, 2, book: book, returned_at: nil)

        expect(book.available?).to be false
      end
    end

    describe "#borrowed_by?" do
      it "returns true if the book is borrowed by the user" do
        user = create(:user)
        book = create(:book)
        create(:borrowing, user: user, book: book, returned_at: nil)

        expect(book.borrowed_by?(user)).to be true
      end

      it "returns false if the book is not borrowed by the user" do
        user = create(:user)
        another_user = create(:user)
        book = create(:book)
        create(:borrowing, user: another_user, book: book, returned_at: nil)

        expect(book.borrowed_by?(user)).to be false
      end
    end
  end
end
