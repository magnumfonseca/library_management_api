# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dashboard API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let(:librarian) { create(:user, :librarian) }
  let(:member) { create(:user, :member) }

  def jwt_token_for(user)
    Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
  end

  path '/api/v1/dashboard' do
    get 'Dashboard (role-aware)' do
      tags 'Dashboard'
      description 'Retrieve dashboard data based on user role (librarian or member)'
      produces 'application/json'
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: 'JWT Bearer token'

      parameter name: :page,
                in: :query,
                type: :integer,
                required: false,
                description: 'Page number (default: 1 for librarian, 1 for member)'

      parameter name: :per_page,
                in: :query,
                type: :integer,
                required: false,
                description: 'Items per page (default: 10 for librarian, 20 for member)'

      response '200', 'Librarian dashboard data retrieved successfully' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     total_books: { type: :integer, example: 100 },
                     total_borrowed_books: { type: :integer, example: 25 },
                     books_due_today: { type: :integer, example: 5 },
                     members_with_overdue: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :integer },
                           name: { type: :string },
                           email: { type: :string },
                           overdue_count: { type: :integer }
                         }
                       }
                     },
                     pagination: {
                       type: :object,
                       properties: {
                         current_page: { type: :integer },
                         total_pages: { type: :integer },
                         total_count: { type: :integer },
                         per_page: { type: :integer }
                       }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let!(:books) { create_list(:book, 10) }
        let!(:borrowings) { create_list(:borrowing, 5, user: member) }
        let!(:due_today) { create(:borrowing, :due_today, user: member) }
        let!(:overdue) { create(:borrowing, :overdue, user: member) }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['data']).to have_key('total_books')
          expect(json['data']).to have_key('total_borrowed_books')
          expect(json['data']).to have_key('books_due_today')
          expect(json['data']).to have_key('members_with_overdue')
          expect(json['data']).to have_key('pagination')

          expect(json['data']['total_books']).to eq(17)  # 10 standalone + 5 in borrowings + 1 due_today + 1 overdue
          expect(json['data']['total_borrowed_books']).to eq(7)
          expect(json['data']['books_due_today']).to eq(1)
          expect(json['data']['members_with_overdue']).to be_an(Array)
          expect(json['data']['pagination']).to be_a(Hash)
        end
      end

      response '200', 'Returns members with overdue books (librarian)' do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:member1) { create(:user, :member) }
        let(:member2) { create(:user, :member) }
        let!(:overdue1) { create_list(:borrowing, 2, :overdue, user: member1) }
        let!(:overdue2) { create(:borrowing, :overdue, user: member2) }

        run_test! do |response|
          json = JSON.parse(response.body)
          members = json['data']['members_with_overdue']
          expect(members.size).to eq(2)
          expect(members.first['overdue_count']).to eq(2)
          expect(members.last['overdue_count']).to eq(1)
        end
      end

      response '200', 'Supports pagination (librarian)' do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:page) { 1 }
        let(:per_page) { 2 }

        before do
          5.times do |i|
            m = create(:user, :member)
            create_list(:borrowing, i + 1, :overdue, user: m)
          end
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['data']['members_with_overdue'].size).to eq(2)
          expect(json['data']['pagination']['current_page']).to eq(1)
          expect(json['data']['pagination']['per_page']).to eq(2)
          expect(json['data']['pagination']['total_count']).to be > 2
        end
      end

      response '200', 'Member dashboard data retrieved successfully' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     borrowed_books: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :integer },
                           book: {
                             type: :object,
                             properties: {
                               id: { type: :integer },
                               title: { type: :string },
                               author: { type: :string }
                             }
                           },
                           borrowed_at: { type: :string, format: 'date-time' },
                           due_date: { type: :string, format: 'date-time' },
                           days_until_due: { type: :integer },
                           is_overdue: { type: :boolean },
                           days_overdue: { type: :integer }
                         }
                       }
                     },
                     overdue_books: { type: :array },
                     summary: {
                       type: :object,
                       properties: {
                         total_borrowed: { type: :integer },
                         total_overdue: { type: :integer }
                       }
                     },
                     pagination: {
                       type: :object,
                       properties: {
                         current_page: { type: :integer },
                         total_pages: { type: :integer },
                         total_count: { type: :integer },
                         per_page: { type: :integer }
                       }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let!(:book1) { create(:book, title: 'Active Book') }
        let!(:book2) { create(:book, title: 'Overdue Book') }
        let!(:active) { create(:borrowing, user: member, book: book1) }
        let!(:overdue) { create(:borrowing, :overdue, user: member, book: book2) }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['data']).to have_key('borrowed_books')
          expect(json['data']).to have_key('overdue_books')
          expect(json['data']).to have_key('summary')
          expect(json['data']).to have_key('pagination')

          expect(json['data']['borrowed_books'].size).to eq(2)
          expect(json['data']['overdue_books'].size).to eq(1)
          expect(json['data']['summary']['total_borrowed']).to eq(2)
          expect(json['data']['summary']['total_overdue']).to eq(1)
        end
      end

      response '200', 'Returns book details in borrowings (member)' do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:book) { create(:book, title: 'Test Book', author: 'Test Author') }
        let!(:borrowing) { create(:borrowing, user: member, book: book) }

        run_test! do |response|
          json = JSON.parse(response.body)
          borrowed = json['data']['borrowed_books'].first
          expect(borrowed['book']['title']).to eq('Test Book')
          expect(borrowed['book']['author']).to eq('Test Author')
          expect(borrowed).to have_key('borrowed_at')
          expect(borrowed).to have_key('due_date')
          expect(borrowed).to have_key('is_overdue')
        end
      end

      response '200', 'Shows empty dashboard for member with no borrowings' do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['data']['borrowed_books']).to be_empty
          expect(json['data']['overdue_books']).to be_empty
          expect(json['data']['summary']['total_borrowed']).to eq(0)
          expect(json['data']['summary']['total_overdue']).to eq(0)
        end
      end

      response '200', 'Supports pagination (member)' do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:page) { 1 }
        let(:per_page) { 5 }

        before do
          10.times do |i|
            book = create(:book, title: "Book #{i}")
            create(:borrowing, user: member, book: book)
          end
        end

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['data']['borrowed_books'].size).to eq(5)
          expect(json['data']['pagination']['current_page']).to eq(1)
          expect(json['data']['pagination']['per_page']).to eq(5)
          expect(json['data']['pagination']['total_count']).to eq(10)
        end
      end

      response '401', 'Requires authentication' do
        let(:Authorization) { '' }

        run_test!
      end

      response '200', 'Handles edge case pagination - page 0 defaults to 1 (librarian)' do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:page) { 0 }
        let!(:member1) { create(:user, :member) }
        let!(:overdue1) { create(:borrowing, :overdue, user: member1) }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['data']['pagination']['current_page']).to eq(1)
        end
      end

      response '200', 'Handles edge case pagination - negative page defaults to 1' do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:page) { -5 }
        let!(:member1) { create(:user, :member) }
        let!(:overdue1) { create(:borrowing, :overdue, user: member1) }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['data']['pagination']['current_page']).to eq(1)
        end
      end

      response '200', 'Handles out of bounds page - returns empty array' do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:page) { 999 }
        let(:per_page) { 10 }
        let!(:member1) { create(:user, :member) }
        let!(:overdue1) { create(:borrowing, :overdue, user: member1) }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['data']['members_with_overdue']).to be_empty
          expect(json['data']['pagination']['current_page']).to eq(999)
        end
      end
    end
  end
end
