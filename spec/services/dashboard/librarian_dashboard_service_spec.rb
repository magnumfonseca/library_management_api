# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::LibrarianDashboardService do
  let(:member) { create(:user, :member) }

  describe '#call' do
    context 'when user is a librarian' do
      let!(:books) { create_list(:book, 5) }
      let!(:active_borrowings) { create_list(:borrowing, 3, user: member) }
      let!(:due_today_borrowing) { create(:borrowing, :due_today, user: member) }
      let!(:overdue_borrowing) { create(:borrowing, :overdue, user: member) }

      it 'returns success with dashboard data' do
        response = described_class.new.call

        expect(response).to be_success
        expect(response.data[:total_books]).to eq(10) # 5 explicit + 5 from borrowings
        expect(response.data[:total_borrowed_books]).to eq(5) # 3 + 1 + 1
        expect(response.data[:books_due_today]).to eq(1)
        expect(response.data[:members_with_overdue]).to be_an(Array)
      end

      it 'returns members with overdue books' do
        response = described_class.new.call

        members_with_overdue = response.data[:members_with_overdue]
        expect(members_with_overdue.size).to eq(1)
        expect(members_with_overdue.first[:id]).to eq(member.id)
        expect(members_with_overdue.first[:overdue_count]).to eq(1)
      end

      it 'orders members by overdue count descending' do
        member2 = create(:user, :member)
        create_list(:borrowing, 3, :overdue, user: member2)

        response = described_class.new.call

        members = response.data[:members_with_overdue]
        expect(members.first[:overdue_count]).to be > members.last[:overdue_count]
      end

      it 'includes pagination metadata' do
        response = described_class.new.call

        expect(response.data[:pagination]).to be_a(Hash)
        expect(response.data[:pagination]).to include(
          current_page: 1,
          total_pages: kind_of(Integer),
          total_count: kind_of(Integer),
          per_page: 10
        )
      end

      context 'with pagination parameters' do
        let(:member1) { create(:user, :member) }
        let(:member2) { create(:user, :member) }
        let(:member3) { create(:user, :member) }

        before do
          create_list(:borrowing, 5, :overdue, user: member1)
          create_list(:borrowing, 3, :overdue, user: member2)
          create_list(:borrowing, 2, :overdue, user: member3)
        end

        it 'respects page parameter' do
          response = described_class.new(page: 1, per_page: 2).call

          expect(response.data[:members_with_overdue].size).to eq(2)
          expect(response.data[:pagination][:current_page]).to eq(1)
          expect(response.data[:pagination][:total_pages]).to eq(2)
        end

        it 'respects per_page parameter' do
          response = described_class.new(page: 1, per_page: 1).call

          expect(response.data[:members_with_overdue].size).to eq(1)
          expect(response.data[:pagination][:per_page]).to eq(1)
          expect(response.data[:pagination][:total_count]).to eq(4) # member + member1 + member2 + member3
        end

        it 'returns correct page 2 data' do
          response_page1 = described_class.new(page: 1, per_page: 2).call
          response_page2 = described_class.new(page: 2, per_page: 2).call

          page1_ids = response_page1.data[:members_with_overdue].map { |m| m[:id] }
          page2_ids = response_page2.data[:members_with_overdue].map { |m| m[:id] }

          expect(page1_ids).not_to include(*page2_ids)
        end
      end
    end

    context 'with no active borrowings' do
      let!(:books) { create_list(:book, 3) }

      it 'returns zero counts' do
        response = described_class.new.call

        expect(response.data[:total_books]).to eq(3)
        expect(response.data[:total_borrowed_books]).to eq(0)
        expect(response.data[:books_due_today]).to eq(0)
        expect(response.data[:members_with_overdue]).to be_empty
      end

      it 'includes empty pagination' do
        response = described_class.new.call

        expect(response.data[:pagination][:total_count]).to eq(0)
        expect(response.data[:pagination][:total_pages]).to eq(0)
      end
    end
  end
end
