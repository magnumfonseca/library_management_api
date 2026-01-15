# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Book Borrowing Workflow", type: :request do
  describe "complete borrowing lifecycle" do
    let!(:book) { create(:book, title: "The Great Gatsby", author: "F. Scott Fitzgerald", total_copies: 3) }
    let!(:librarian) { create(:user, :librarian) }

    it "allows a user to register, borrow a book, and have it returned by a librarian" do
      # Step 1: User registers
      post "/api/v1/signup", params: {
        user: {
          email: "newmember@example.com",
          password: "password123",
          password_confirmation: "password123",
          name: "New Member"
        }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["data"]["attributes"]["email"]).to eq("newmember@example.com")
      expect(json_response["data"]["attributes"]["role"]).to eq("member")

      # Capture the JWT token from registration
      member_token = response.headers["Authorization"]
      expect(member_token).to be_present

      # Step 2: Member borrows a book
      post "/api/v1/borrowings", params: {
        borrowing: { book_id: book.id }
      }, headers: { "Authorization" => member_token }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response["data"]["type"]).to eq("borrowings")
      expect(json_response["data"]["attributes"]["book_title"]).to eq("The Great Gatsby")
      expect(json_response["data"]["attributes"]["status"]).to eq("active")

      borrowing_id = json_response["data"]["id"]
      due_date = json_response["data"]["attributes"]["due_date"]

      # Verify due date is approximately 14 days from now
      expected_due_date = 14.days.from_now.to_date
      actual_due_date = Date.parse(due_date)
      expect(actual_due_date).to eq(expected_due_date)

      # Verify member cannot borrow the same book again
      post "/api/v1/borrowings", params: {
        borrowing: { book_id: book.id }
      }, headers: { "Authorization" => member_token }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["errors"].first["detail"]).to include("already have an active borrowing")

      # Step 3: Verify member can see their borrowing in the dashboard
      get "/api/v1/dashboard", headers: { "Authorization" => member_token }

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]["borrowed_books"]).to be_an(Array)
      expect(json_response["data"]["borrowed_books"].length).to eq(1)
      expect(json_response["data"]["borrowed_books"].first["book"]["title"]).to eq("The Great Gatsby")

      # Step 4: Member cannot return their own book (only librarians can)
      patch "/api/v1/borrowings/#{borrowing_id}/return",
            headers: { "Authorization" => member_token }, as: :json

      expect(response).to have_http_status(:forbidden)

      # Step 5: Librarian returns the book
      librarian_token = "Bearer #{Warden::JWTAuth::UserEncoder.new.call(librarian, :user, nil).first}"

      patch "/api/v1/borrowings/#{borrowing_id}/return",
            headers: { "Authorization" => librarian_token }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]["attributes"]["status"]).to eq("returned")
      expect(json_response["data"]["attributes"]["returned_at"]).to be_present

      # Step 6: Verify member can now borrow the same book again
      post "/api/v1/borrowings", params: {
        borrowing: { book_id: book.id }
      }, headers: { "Authorization" => member_token }, as: :json

      expect(response).to have_http_status(:created)

      # Step 7: Verify member dashboard shows updated borrowings
      get "/api/v1/dashboard", headers: { "Authorization" => member_token }

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]["borrowed_books"].length).to eq(1)
    end
  end

  describe "book availability tracking" do
    let!(:book) { create(:book, title: "Limited Book", total_copies: 1) }

    it "prevents borrowing when no copies are available" do
      # First member borrows the only copy
      member1 = create(:user, :member, email: "member1@example.com")
      member1_token = "Bearer #{Warden::JWTAuth::UserEncoder.new.call(member1, :user, nil).first}"

      post "/api/v1/borrowings", params: {
        borrowing: { book_id: book.id }
      }, headers: { "Authorization" => member1_token }, as: :json

      expect(response).to have_http_status(:created)

      # Second member tries to borrow - should fail
      member2 = create(:user, :member, email: "member2@example.com")
      member2_token = "Bearer #{Warden::JWTAuth::UserEncoder.new.call(member2, :user, nil).first}"

      post "/api/v1/borrowings", params: {
        borrowing: { book_id: book.id }
      }, headers: { "Authorization" => member2_token }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response["errors"].first["detail"]).to include("not available")

      # Librarian returns the book
      librarian = create(:user, :librarian)
      librarian_token = "Bearer #{Warden::JWTAuth::UserEncoder.new.call(librarian, :user, nil).first}"

      borrowing_id = Borrowing.last.id
      patch "/api/v1/borrowings/#{borrowing_id}/return",
            headers: { "Authorization" => librarian_token }, as: :json

      expect(response).to have_http_status(:ok)

      # Now second member can borrow
      post "/api/v1/borrowings", params: {
        borrowing: { book_id: book.id }
      }, headers: { "Authorization" => member2_token }, as: :json

      expect(response).to have_http_status(:created)
    end
  end

  describe "librarian dashboard tracking" do
    it "shows overdue books and borrowing statistics" do
      librarian = create(:user, :librarian)
      librarian_token = "Bearer #{Warden::JWTAuth::UserEncoder.new.call(librarian, :user, nil).first}"

      # Create some books and borrowings
      book1 = create(:book, title: "Book 1")
      book2 = create(:book, title: "Book 2")
      book3 = create(:book, title: "Book 3")
      member = create(:user, :member)

      # Create an overdue borrowing
      create(:borrowing,
             user: member,
             book: book1,
             borrowed_at: 20.days.ago,
             due_date: 6.days.ago,
             returned_at: nil)

      # Create a borrowing due today
      create(:borrowing,
             user: member,
             book: book2,
             borrowed_at: 14.days.ago,
             due_date: Date.current,
             returned_at: nil)

      # Create an active (not yet due) borrowing
      create(:borrowing,
             user: member,
             book: book3,
             borrowed_at: 1.day.ago,
             due_date: 13.days.from_now,
             returned_at: nil)

      # Check librarian dashboard
      get "/api/v1/dashboard", headers: { "Authorization" => librarian_token }

      expect(response).to have_http_status(:ok)
      dashboard = json_response["data"]

      expect(dashboard["total_books"]).to eq(3)
      expect(dashboard["total_borrowed_books"]).to eq(3)
      expect(dashboard["books_due_today"]).to eq(1)
      expect(dashboard["members_with_overdue"]).to be_an(Array)
      expect(dashboard["members_with_overdue"].length).to eq(1)
      # Member has overdue books (may include due today depending on system definition)
      expect(dashboard["members_with_overdue"].first["overdue_count"]).to be >= 1
    end
  end
end
