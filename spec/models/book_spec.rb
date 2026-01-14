# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Book, type: :model do
  describe 'validations' do
    subject { build(:book) }

    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:author) }
    it { should validate_presence_of(:genre) }
    it { should validate_presence_of(:isbn) }
    it { should validate_numericality_of(:total_copies).is_greater_than(0) }
  end

  describe 'scopes' do
    describe '.by_genre' do
      it 'returns books of the specified genre' do
        fantasy_book = create(:book, genre: 'Fantasy')
        mystery_book = create(:book, genre: 'Mystery')

        result = Book.by_genre('Fantasy')
        expect(result).to include(fantasy_book)
        expect(result).not_to include(mystery_book)
      end
    end

    describe '.by_author' do
      it 'returns books by the specified author' do
        rowling_book = create(:book, author: 'J.K. Rowling')
        tolkien_book = create(:book, author: 'J.R.R. Tolkien')

        result = Book.by_author('Rowling')
        expect(result).to include(rowling_book)
        expect(result).not_to include(tolkien_book)
      end
    end
  end
end
