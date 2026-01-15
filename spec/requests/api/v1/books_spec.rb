# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Books API", type: :request do
  let(:librarian) { create(:user, :librarian) }
  let(:member) { create(:user, :member) }

  describe "GET /api/v1/books" do
    context "when authenticated" do
      before { create_list(:book, 3) }

      it "returns ok status" do
        auth_get "/api/v1/books", user: member

        expect(response).to have_http_status(:ok)
      end

      it "returns all books in JSON:API format" do
        auth_get "/api/v1/books", user: member

        expect(json_response).to have_key("data")
        expect(json_response["data"].size).to eq(3)
        expect(json_response["data"].first).to have_key("type")
        expect(json_response["data"].first["type"]).to eq("books")
      end

      it "returns book attributes" do
        book = create(:book, title: "Test Book", author: "Test Author", genre: "Fiction", isbn: "1234567890", total_copies: 5)

        auth_get "/api/v1/books", user: member

        book_data = json_response["data"].find { |b| b["id"] == book.id.to_s }
        expect(book_data["attributes"]["title"]).to eq("Test Book")
        expect(book_data["attributes"]["author"]).to eq("Test Author")
        expect(book_data["attributes"]["genre"]).to eq("Fiction")
        expect(book_data["attributes"]["isbn"]).to eq("1234567890")
        expect(book_data["attributes"]["total_copies"]).to eq(5)
        expect(book_data["attributes"]["available_copies"]).to eq(5)
      end

      it "allows both members and librarians to list books" do
        auth_get "/api/v1/books", user: librarian

        expect(response).to have_http_status(:ok)
      end
    end

    context "when not authenticated" do
      it "returns unauthorized status" do
        get "/api/v1/books", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/books/:id" do
    let!(:book) { create(:book, title: "Specific Book", author: "Specific Author") }

    context "when authenticated" do
      it "returns ok status" do
        auth_get "/api/v1/books/#{book.id}", user: member

        expect(response).to have_http_status(:ok)
      end

      it "returns the book in JSON:API format" do
        auth_get "/api/v1/books/#{book.id}", user: member

        expect(json_response).to have_key("data")
        expect(json_response["data"]["type"]).to eq("books")
        expect(json_response["data"]["id"]).to eq(book.id.to_s)
        expect(json_response["data"]["attributes"]["title"]).to eq("Specific Book")
        expect(json_response["data"]["attributes"]["author"]).to eq("Specific Author")
      end

      it "returns available_copies correctly" do
        create(:borrowing, book: book)

        auth_get "/api/v1/books/#{book.id}", user: member

        expect(json_response["data"]["attributes"]["available_copies"]).to eq(book.available_copies)
      end
    end

    context "when book does not exist" do
      it "returns not found status" do
        auth_get "/api/v1/books/999999", user: member

        expect(response).to have_http_status(:not_found)
      end

      it "returns error in JSON:API format" do
        auth_get "/api/v1/books/999999", user: member

        expect(json_response).to have_key("errors")
        expect(json_response["errors"].first["status"]).to eq("404")
      end
    end

    context "when not authenticated" do
      it "returns unauthorized status" do
        get "/api/v1/books/#{book.id}", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/books" do
    let(:valid_params) do
      {
        book: {
          title: "New Book",
          author: "New Author",
          genre: "Fiction",
          isbn: "9781234567890",
          total_copies: 5
        }
      }
    end

    context "when user is a librarian" do
      it "returns created status" do
        auth_post "/api/v1/books", params: valid_params, user: librarian

        expect(response).to have_http_status(:created)
      end

      it "creates a new book" do
        expect {
          auth_post "/api/v1/books", params: valid_params, user: librarian
        }.to change(Book, :count).by(1)
      end

      it "returns the created book in JSON:API format" do
        auth_post "/api/v1/books", params: valid_params, user: librarian

        expect(json_response).to have_key("data")
        expect(json_response["data"]["type"]).to eq("books")
        expect(json_response["data"]["attributes"]["title"]).to eq("New Book")
        expect(json_response["data"]["attributes"]["author"]).to eq("New Author")
        expect(json_response["data"]["attributes"]["genre"]).to eq("Fiction")
        expect(json_response["data"]["attributes"]["isbn"]).to eq("9781234567890")
        expect(json_response["data"]["attributes"]["total_copies"]).to eq(5)
        expect(json_response["data"]["attributes"]["available_copies"]).to eq(5)
      end

      it "returns success message in meta" do
        auth_post "/api/v1/books", params: valid_params, user: librarian

        expect(json_response["meta"]["message"]).to eq("Book created successfully.")
      end
    end

    context "when user is a member" do
      it "returns forbidden status" do
        auth_post "/api/v1/books", params: valid_params, user: member

        expect(response).to have_http_status(:forbidden)
      end

      it "does not create a book" do
        expect {
          auth_post "/api/v1/books", params: valid_params, user: member
        }.not_to change(Book, :count)
      end
    end

    context "with invalid parameters" do
      it "returns unprocessable entity for missing title" do
        invalid_params = valid_params.deep_dup
        invalid_params[:book][:title] = ""

        auth_post "/api/v1/books", params: invalid_params, user: librarian

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response["errors"]).to be_present
      end

      it "returns unprocessable entity for duplicate ISBN" do
        create(:book, isbn: "9781234567890")

        auth_post "/api/v1/books", params: valid_params, user: librarian

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response["errors"]).to be_present
      end

      it "returns unprocessable entity for invalid total_copies" do
        invalid_params = valid_params.deep_dup
        invalid_params[:book][:total_copies] = 0

        auth_post "/api/v1/books", params: invalid_params, user: librarian

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when not authenticated" do
      it "returns unauthorized status" do
        post "/api/v1/books", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/books/:id" do
    let!(:book) { create(:book, title: "Original Title", author: "Original Author", total_copies: 5) }
    let(:update_params) { { book: { title: "Updated Title" } } }

    context "when user is a librarian" do
      it "returns ok status" do
        auth_patch "/api/v1/books/#{book.id}", params: update_params, user: librarian

        expect(response).to have_http_status(:ok)
      end

      it "updates the book" do
        auth_patch "/api/v1/books/#{book.id}", params: update_params, user: librarian

        expect(book.reload.title).to eq("Updated Title")
      end

      it "returns the updated book in JSON:API format" do
        auth_patch "/api/v1/books/#{book.id}", params: update_params, user: librarian

        expect(json_response["data"]["attributes"]["title"]).to eq("Updated Title")
        expect(json_response["data"]["attributes"]["author"]).to eq("Original Author")
      end

      it "returns success message in meta" do
        auth_patch "/api/v1/books/#{book.id}", params: update_params, user: librarian

        expect(json_response["meta"]["message"]).to eq("Book updated successfully.")
      end

      it "can update multiple attributes" do
        auth_patch "/api/v1/books/#{book.id}",
                   params: { book: { title: "New Title", author: "New Author", genre: "Science" } },
                   user: librarian

        expect(response).to have_http_status(:ok)
        expect(json_response["data"]["attributes"]["title"]).to eq("New Title")
        expect(json_response["data"]["attributes"]["author"]).to eq("New Author")
        expect(json_response["data"]["attributes"]["genre"]).to eq("Science")
      end
    end

    context "when user is a member" do
      it "returns forbidden status" do
        auth_patch "/api/v1/books/#{book.id}", params: update_params, user: member

        expect(response).to have_http_status(:forbidden)
      end

      it "does not update the book" do
        auth_patch "/api/v1/books/#{book.id}", params: update_params, user: member

        expect(book.reload.title).to eq("Original Title")
      end
    end

    context "with invalid parameters" do
      it "returns unprocessable entity for empty title" do
        auth_patch "/api/v1/books/#{book.id}",
                   params: { book: { title: "" } },
                   user: librarian

        expect(response).to have_http_status(:unprocessable_content)
      end

      it "returns unprocessable entity for duplicate ISBN" do
        other_book = create(:book)

        auth_patch "/api/v1/books/#{book.id}",
                   params: { book: { isbn: other_book.isbn } },
                   user: librarian

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when book does not exist" do
      it "returns not found status" do
        auth_patch "/api/v1/books/999999", params: update_params, user: librarian

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not authenticated" do
      it "returns unauthorized status" do
        patch "/api/v1/books/#{book.id}", params: update_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/books/:id" do
    let!(:book) { create(:book) }

    context "when user is a librarian" do
      context "with no active borrowings" do
        it "returns no content status" do
          auth_delete "/api/v1/books/#{book.id}", user: librarian

          expect(response).to have_http_status(:no_content)
        end

        it "deletes the book" do
          expect {
            auth_delete "/api/v1/books/#{book.id}", user: librarian
          }.to change(Book, :count).by(-1)
        end
      end

      context "with active borrowings" do
        before { create(:borrowing, book: book) }

        it "returns unprocessable entity status" do
          auth_delete "/api/v1/books/#{book.id}", user: librarian

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "does not delete the book" do
          expect {
            auth_delete "/api/v1/books/#{book.id}", user: librarian
          }.not_to change(Book, :count)
        end

        it "returns error message" do
          auth_delete "/api/v1/books/#{book.id}", user: librarian

          expect(json_response["errors"]).to be_present
          expect(json_response["errors"].first["detail"]).to include("active borrowings")
        end
      end

      context "with only returned borrowings" do
        before { create(:borrowing, :returned, book: book) }

        it "allows deletion" do
          expect {
            auth_delete "/api/v1/books/#{book.id}", user: librarian
          }.to change(Book, :count).by(-1)
        end
      end
    end

    context "when user is a member" do
      it "returns forbidden status" do
        auth_delete "/api/v1/books/#{book.id}", user: member

        expect(response).to have_http_status(:forbidden)
      end

      it "does not delete the book" do
        expect {
          auth_delete "/api/v1/books/#{book.id}", user: member
        }.not_to change(Book, :count)
      end
    end

    context "when book does not exist" do
      it "returns not found status" do
        auth_delete "/api/v1/books/999999", user: librarian

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when not authenticated" do
      it "returns unauthorized status" do
        delete "/api/v1/books/#{book.id}", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
