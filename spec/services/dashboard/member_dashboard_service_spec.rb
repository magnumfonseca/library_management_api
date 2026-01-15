# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::MemberDashboardService do
  let(:member) { create(:user, :member) }
  let(:librarian) { create(:user, :librarian) }

  describe '#call' do
    context 'when user is a member' do
      let!(:book1) { create(:book, title: 'Book 1') }
      let!(:book2) { create(:book, title: 'Book 2') }
      let!(:active_borrowing) { create(:borrowing, user: member, book: book1) }
      let!(:overdue_borrowing) { create(:borrowing, :overdue, user: member, book: book2) }

      it 'returns success with dashboard data' do
        response = described_class.new(current_user: member).call

        expect(response).to be_success
        expect(response.data[:borrowed_books]).to be_an(Array)
        expect(response.data[:overdue_books]).to be_an(Array)
        expect(response.data[:summary]).to be_a(Hash)
      end

      it 'returns all borrowed books' do
        response = described_class.new(current_user: member).call

        expect(response.data[:borrowed_books].size).to eq(2)
        expect(response.data[:summary][:total_borrowed]).to eq(2)
      end

      it 'returns only overdue books in overdue section' do
        response = described_class.new(current_user: member).call

        expect(response.data[:overdue_books].size).to eq(1)
        expect(response.data[:summary][:total_overdue]).to eq(1)
      end

      it 'includes book details in borrowing data' do
        response = described_class.new(current_user: member).call

        borrowing_data = response.data[:borrowed_books].first
        expect(borrowing_data[:book]).to include(
          id: kind_of(Integer),
          title: kind_of(String),
          author: kind_of(String)
        )
      end

      it 'includes borrowing dates and status' do
        response = described_class.new(current_user: member).call

        borrowing_data = response.data[:borrowed_books].first
        expect(borrowing_data).to include(
          borrowed_at: kind_of(ActiveSupport::TimeWithZone),
          due_date: kind_of(ActiveSupport::TimeWithZone),
          days_overdue: kind_of(Integer)
        )
        expect(borrowing_data[:is_overdue]).to be_in([ true, false ])
      end

      it 'calculates days until due for active borrowings' do
        response = described_class.new(current_user: member).call

        active = response.data[:borrowed_books].find { |b| !b[:is_overdue] }
        expect(active[:days_until_due]).to be > 0
      end

      it 'orders borrowings by due date ascending' do
        create(:borrowing, user: member, due_date: 1.day.from_now)
        create(:borrowing, user: member, due_date: 7.days.from_now)

        response = described_class.new(current_user: member).call

        due_dates = response.data[:borrowed_books].map { |b| b[:due_date] }
        expect(due_dates).to eq(due_dates.sort)
      end

      it 'includes pagination metadata' do
        response = described_class.new(current_user: member).call

        expect(response.data[:pagination]).to be_a(Hash)
        expect(response.data[:pagination]).to include(
          current_page: 1,
          total_pages: kind_of(Integer),
          total_count: kind_of(Integer),
          per_page: 20
        )
      end

      context 'with pagination parameters' do
        before do
          # Create 25 borrowed books to test pagination
          25.times do |i|
            book = create(:book, title: "Book #{i}")
            create(:borrowing, user: member, book: book, due_date: (i + 1).days.from_now)
          end
        end

        it 'respects page parameter' do
          response = described_class.new(current_user: member, page: 1, per_page: 10).call

          expect(response.data[:borrowed_books].size).to eq(10)
          expect(response.data[:pagination][:current_page]).to eq(1)
        end

        it 'respects per_page parameter' do
          response = described_class.new(current_user: member, page: 1, per_page: 5).call

          expect(response.data[:borrowed_books].size).to eq(5)
          expect(response.data[:pagination][:per_page]).to eq(5)
          expect(response.data[:pagination][:total_count]).to eq(27) # 25 + 2 from before block
        end

        it 'returns correct total pages' do
          response = described_class.new(current_user: member, page: 1, per_page: 10).call

          expect(response.data[:pagination][:total_pages]).to eq(3) # 27 / 10 = 3 pages
        end

        it 'returns correct page 2 data' do
          response_page1 = described_class.new(current_user: member, page: 1, per_page: 10).call
          response_page2 = described_class.new(current_user: member, page: 2, per_page: 10).call

          page1_ids = response_page1.data[:borrowed_books].map { |b| b[:id] }
          page2_ids = response_page2.data[:borrowed_books].map { |b| b[:id] }

          expect(page1_ids).not_to include(*page2_ids)
          expect(response_page2.data[:borrowed_books].size).to eq(10)
        end

        it 'summary reflects total count not paginated count' do
          response = described_class.new(current_user: member, page: 1, per_page: 5).call

          expect(response.data[:borrowed_books].size).to eq(5)
          expect(response.data[:summary][:total_borrowed]).to eq(27)
        end
      end
    end

    context 'with no borrowings' do
      it 'returns empty arrays' do
        response = described_class.new(current_user: member).call

        expect(response.data[:borrowed_books]).to be_empty
        expect(response.data[:overdue_books]).to be_empty
        expect(response.data[:summary][:total_borrowed]).to eq(0)
        expect(response.data[:summary][:total_overdue]).to eq(0)
      end

      it 'includes empty pagination' do
        response = described_class.new(current_user: member).call

        expect(response.data[:pagination][:total_count]).to eq(0)
        expect(response.data[:pagination][:total_pages]).to eq(0)
      end
    end

    context 'with only returned borrowings' do
      let!(:returned_borrowing) { create(:borrowing, :returned, user: member) }

      it 'does not include returned books' do
        response = described_class.new(current_user: member).call

        expect(response.data[:borrowed_books]).to be_empty
      end
    end
  end
end
