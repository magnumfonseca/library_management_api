# frozen_string_literal: true

require "rails_helper"

RSpec.describe Filterable, type: :controller do
  # Create a test controller that includes the concern
  controller(ActionController::API) do
    include Filterable

    def index
      scope = Book.all
      filtered_scope = apply_filters(scope, %i[title author genre])
      render json: { count: filtered_scope.count }
    end

    def borrowings
      scope = Borrowing.all
      filtered_scope = apply_scope_filter(scope, :status, %w[active returned overdue])
      render json: { count: filtered_scope.count }
    end
  end

  before do
    routes.draw do
      get "index" => "anonymous#index"
      get "borrowings" => "anonymous#borrowings"
    end
  end

  describe "#apply_filters" do
    let!(:book1) { create(:book, title: "The Great Gatsby", author: "F. Scott Fitzgerald", genre: "Fiction") }
    let!(:book2) { create(:book, title: "1984", author: "George Orwell", genre: "Dystopian") }
    let!(:book3) { create(:book, title: "To Kill a Mockingbird", author: "Harper Lee", genre: "Fiction") }

    context "with title filter" do
      it "filters by title when title param is present" do
        get :index, params: { title: "1984" }
        expect(JSON.parse(response.body)["count"]).to eq(1)
      end

      it "returns all records when title param is not present" do
        get :index, params: {}
        expect(JSON.parse(response.body)["count"]).to eq(3)
      end

      it "returns no results when title doesn't match" do
        get :index, params: { title: "Nonexistent Book" }
        expect(JSON.parse(response.body)["count"]).to eq(0)
      end
    end

    context "with author filter" do
      it "filters by author when author param is present" do
        get :index, params: { author: "George Orwell" }
        expect(JSON.parse(response.body)["count"]).to eq(1)
      end

      it "returns all records when author param is not present" do
        get :index, params: {}
        expect(JSON.parse(response.body)["count"]).to eq(3)
      end
    end

    context "with genre filter" do
      it "filters by genre when genre param is present" do
        get :index, params: { genre: "Fiction" }
        expect(JSON.parse(response.body)["count"]).to eq(2)
      end

      it "returns all records when genre param is not present" do
        get :index, params: {}
        expect(JSON.parse(response.body)["count"]).to eq(3)
      end
    end

    context "with multiple filters" do
      it "applies multiple filters simultaneously" do
        get :index, params: { genre: "Fiction", author: "F. Scott Fitzgerald" }
        expect(JSON.parse(response.body)["count"]).to eq(1)
      end

      it "returns no results when filters don't match any record" do
        get :index, params: { genre: "Fiction", author: "George Orwell" }
        expect(JSON.parse(response.body)["count"]).to eq(0)
      end
    end

    context "with non-existent filter" do
      it "ignores filters that don't have corresponding scopes" do
        get :index, params: { nonexistent_filter: "value" }
        expect(JSON.parse(response.body)["count"]).to eq(3)
      end
    end

    context "with empty filter values" do
      it "ignores empty string filters" do
        get :index, params: { title: "" }
        expect(JSON.parse(response.body)["count"]).to eq(3)
      end

      it "ignores nil filters" do
        get :index, params: { title: nil }
        expect(JSON.parse(response.body)["count"]).to eq(3)
      end
    end
  end

  describe "#apply_scope_filter" do
    let!(:user) { create(:user) }
    let!(:book1) { create(:book) }
    let!(:book2) { create(:book) }
    let!(:book3) { create(:book) }
    let!(:active_borrowing) { create(:borrowing, user: user, book: book1, borrowed_at: 2.days.ago, due_date: 5.days.from_now, returned_at: nil) }
    let!(:returned_borrowing) { create(:borrowing, user: user, book: book2, borrowed_at: 20.days.ago, due_date: 6.days.ago, returned_at: 3.days.ago) }
    let!(:overdue_borrowing) { create(:borrowing, user: user, book: book3, borrowed_at: 20.days.ago, due_date: 3.days.ago, returned_at: nil) }

    context "with valid status filter" do
      it "filters by active status" do
        get :borrowings, params: { status: "active" }
        # Active includes both on-time and overdue unreturned borrowings
        expect(JSON.parse(response.body)["count"]).to eq(2)
      end

      it "filters by returned status" do
        get :borrowings, params: { status: "returned" }
        expect(JSON.parse(response.body)["count"]).to eq(1)
      end

      it "filters by overdue status" do
        get :borrowings, params: { status: "overdue" }
        expect(JSON.parse(response.body)["count"]).to eq(1)
      end
    end

    context "with invalid status filter" do
      it "ignores invalid status values" do
        get :borrowings, params: { status: "invalid_status" }
        expect(JSON.parse(response.body)["count"]).to eq(3)
      end

      it "ignores status values not in whitelist" do
        get :borrowings, params: { status: "pending" }
        expect(JSON.parse(response.body)["count"]).to eq(3)
      end
    end

    context "without status filter" do
      it "returns all records when status param is not present" do
        get :borrowings, params: {}
        expect(JSON.parse(response.body)["count"]).to eq(3)
      end

      it "returns all records when status param is empty" do
        get :borrowings, params: { status: "" }
        expect(JSON.parse(response.body)["count"]).to eq(3)
      end

      it "returns all records when status param is nil" do
        get :borrowings, params: { status: nil }
        expect(JSON.parse(response.body)["count"]).to eq(3)
      end
    end

    context "security - prevents arbitrary method execution" do
      it "does not execute arbitrary methods via public_send" do
        # Attempting to call a dangerous method should be ignored
        expect {
          get :borrowings, params: { status: "destroy_all" }
        }.not_to change(Borrowing, :count)

        expect(JSON.parse(response.body)["count"]).to eq(3)
      end

      it "only allows whitelisted scope names" do
        # Attempting to call a valid ActiveRecord method that's not whitelisted
        get :borrowings, params: { status: "all" }
        expect(JSON.parse(response.body)["count"]).to eq(3)
      end
    end
  end
end
