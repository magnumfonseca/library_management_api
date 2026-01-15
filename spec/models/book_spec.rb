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
    describe ".by_title" do
      it "returns books with titles containing the search term (case-insensitive)" do
        ruby_book = create(:book, title: "Learning Ruby")
        rails_book = create(:book, title: "Ruby on Rails Guide")
        python_book = create(:book, title: "Python Basics")

        result = Book.by_title("ruby")
        expect(result).to include(ruby_book)
        expect(result).to include(rails_book)
        expect(result).not_to include(python_book)
      end

      it "returns partial matches" do
        book = create(:book, title: "The Great Gatsby")

        expect(Book.by_title("Great")).to include(book)
        expect(Book.by_title("Gatsby")).to include(book)
        expect(Book.by_title("at Gat")).to include(book)
      end
    end

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

    describe '.available' do
      let!(:book_no_borrows) { create(:book, total_copies: 1) }
      let!(:book_all_returned) do
        b = create(:book, total_copies: 1)
        create(:borrowing, book: b, returned_at: 1.day.ago)
        b
      end
      let!(:book_active) do
        b = create(:book, total_copies: 1)
        create(:borrowing, book: b, returned_at: nil)
        b
      end

      it 'includes books with no borrowings' do
        expect(Book.available).to include(book_no_borrows)
      end

      it 'includes books whose borrowings are all returned' do
        expect(Book.available).to include(book_all_returned)
      end

      it 'excludes books fully borrowed' do
        expect(Book.available).not_to include(book_active)
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
