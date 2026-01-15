# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Books API", type: :request, openapi_spec: "v1/swagger.yaml" do
  let(:librarian) { create(:user, :librarian) }
  let(:member) { create(:user, :member) }

  # Helper to generate JWT token for a user
  def jwt_token_for(user)
    Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
  end

  path "/api/v1/books" do
    get "List all books" do
      tags "Books"
      description "Retrieve a paginated list of all books in the library. Available to all authenticated users."
      produces "application/vnd.api+json"
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: "JWT Bearer token"

      parameter name: :page,
                in: :query,
                type: :integer,
                required: false,
                description: "Page number (default: 1)"

      parameter name: :per_page,
                in: :query,
                type: :integer,
                required: false,
                description: "Number of items per page (default: 25, max: 100)"

      parameter name: "page[number]",
                in: :query,
                type: :integer,
                required: false,
                description: "Page number (JSON:API style)"

      parameter name: "page[size]",
                in: :query,
                type: :integer,
                required: false,
                description: "Page size (JSON:API style)"

      response "200", "Books retrieved successfully" do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, example: "books" },
                       attributes: {
                         type: :object,
                         properties: {
                           title: { type: :string },
                           author: { type: :string },
                           genre: { type: :string },
                           isbn: { type: :string },
                           total_copies: { type: :integer },
                           available_copies: { type: :integer }
                         }
                       }
                     }
                   }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     page: {
                       type: :object,
                       properties: {
                         total: { type: :integer, description: "Total number of records" },
                         totalPages: { type: :integer, description: "Total number of pages" },
                         number: { type: :integer, description: "Current page number" },
                         size: { type: :integer, description: "Number of records per page" }
                       }
                     }
                   }
                 },
                 links: {
                   type: :object,
                   properties: {
                     self: { type: :string },
                     first: { type: :string },
                     last: { type: :string },
                     prev: { type: :string, nullable: true },
                     next: { type: :string, nullable: true }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }

        before { create_list(:book, 3) }

        run_test! do |response|
          expect(json_response).to have_key("data")
          expect(json_response["data"].size).to eq(3)
          expect(json_response["data"].first).to have_key("type")
          expect(json_response["data"].first["type"]).to eq("books")
          expect(json_response["meta"]["page"]).to include(
            "total" => 3,
            "totalPages" => 1,
            "number" => 1,
            "size" => 25
          )
          expect(json_response["links"]).to have_key("self")
          expect(json_response["links"]).to have_key("first")
        end
      end

      response "200", "Returns book attributes correctly" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }

        before do
          create(:book, title: "Test Book", author: "Test Author", genre: "Fiction", isbn: "1234567890", total_copies: 5)
        end

        run_test! do |response|
          book_data = json_response["data"].first
          expect(book_data["attributes"]["title"]).to eq("Test Book")
          expect(book_data["attributes"]["author"]).to eq("Test Author")
          expect(book_data["attributes"]["genre"]).to eq("Fiction")
          expect(book_data["attributes"]["isbn"]).to eq("1234567890")
          expect(book_data["attributes"]["total_copies"]).to eq(5)
          expect(book_data["attributes"]["available_copies"]).to eq(5)
        end
      end

      response "200", "Allows librarians to list books" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }

        before { create_list(:book, 2) }

        run_test!
      end

      response "200", "Returns paginated results with default pagination" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }

        before { create_list(:book, 30) }

        run_test! do |response|
          expect(json_response["data"].size).to eq(25)
          expect(json_response["meta"]["page"]["total"]).to eq(30)
          expect(json_response["meta"]["page"]["totalPages"]).to eq(2)
          expect(json_response["meta"]["page"]["number"]).to eq(1)
          expect(json_response["meta"]["page"]["size"]).to eq(25)
          expect(CGI.unescape(json_response["links"]["next"])).to include("page[number]=2")
        end
      end

      response "200", "Returns correct page with page parameter" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:page) { 2 }
        let(:per_page) { 10 }

        before { create_list(:book, 25) }

        run_test! do |response|
          expect(json_response["data"].size).to eq(10)
          expect(json_response["meta"]["page"]["number"]).to eq(2)
          expect(json_response["meta"]["page"]["total"]).to eq(25)
          expect(CGI.unescape(json_response["links"]["prev"])).to include("page[number]=1")
          expect(CGI.unescape(json_response["links"]["next"])).to include("page[number]=3")
        end
      end

      response "200", "Returns correct page with JSON:API style pagination" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:"page[number]") { 2 }
        let(:"page[size]") { 5 }

        before { create_list(:book, 15) }

        run_test! do |response|
          expect(json_response["data"].size).to eq(5)
          expect(json_response["meta"]["page"]["number"]).to eq(2)
          expect(json_response["meta"]["page"]["size"]).to eq(5)
        end
      end

      response "200", "Returns empty array for page beyond range" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:page) { 999 }

        before { create_list(:book, 5) }

        run_test! do |response|
          expect(json_response["data"]).to eq([])
          expect(json_response["meta"]["page"]["total"]).to eq(5)
          expect(json_response["meta"]["page"]["number"]).to eq(999)
          expect(json_response["links"]["next"]).to be_nil
        end
      end

      response "200", "Caps per_page at maximum" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:per_page) { 500 }

        before { create_list(:book, 150) }

        run_test! do |response|
          expect(json_response["data"].size).to eq(100)
          expect(json_response["meta"]["page"]["size"]).to eq(100)
        end
      end

      response "401", "Unauthorized - Missing or invalid token" do
        let(:Authorization) { nil }

        run_test!
      end
    end

    post "Create a new book" do
      tags "Books"
      description "Create a new book in the library. Only librarians can create books."
      consumes "application/json"
      produces "application/vnd.api+json"
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: "JWT Bearer token"

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          book: {
            type: :object,
            properties: {
              title: { type: :string, description: "Book title" },
              author: { type: :string, description: "Author name" },
              genre: { type: :string, description: "Book genre" },
              isbn: { type: :string, description: "ISBN-10 or ISBN-13" },
              total_copies: { type: :integer, description: "Total number of copies" }
            },
            required: %w[title author total_copies]
          }
        },
        required: %w[book]
      }

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

      response "201", "Book created successfully" do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string, example: "books" },
                     attributes: {
                       type: :object,
                       properties: {
                         title: { type: :string },
                         author: { type: :string },
                         genre: { type: :string },
                         isbn: { type: :string },
                         total_copies: { type: :integer },
                         available_copies: { type: :integer }
                       }
                     }
                   }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     message: { type: :string }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:body) { valid_params }

        run_test! do |response|
          expect(json_response).to have_key("data")
          expect(json_response["data"]["type"]).to eq("books")
          expect(json_response["data"]["attributes"]["title"]).to eq("New Book")
          expect(json_response["data"]["attributes"]["author"]).to eq("New Author")
          expect(json_response["data"]["attributes"]["genre"]).to eq("Fiction")
          expect(json_response["data"]["attributes"]["isbn"]).to eq("9781234567890")
          expect(json_response["data"]["attributes"]["total_copies"]).to eq(5)
          expect(json_response["data"]["attributes"]["available_copies"]).to eq(5)
          expect(json_response["meta"]["message"]).to eq("Book created successfully.")
        end
      end

      response "201", "Creates a new book record" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:body) { valid_params }

        run_test! do
          expect(Book.count).to eq(1)
        end
      end

      response "403", "Forbidden - Only librarians can create books" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:body) { valid_params }

        run_test!
      end

      response "422", "Validation error - Missing title" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:body) do
          { book: valid_params[:book].merge(title: "") }
        end

        run_test! do |response|
          expect(json_response["errors"]).to be_present
        end
      end

      response "422", "Validation error - Duplicate ISBN" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:body) { valid_params }

        before { create(:book, isbn: "9781234567890") }

        run_test! do |response|
          expect(json_response["errors"]).to be_present
        end
      end

      response "422", "Validation error - Invalid total_copies" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:body) do
          { book: valid_params[:book].merge(total_copies: 0) }
        end

        run_test!
      end

      response "401", "Unauthorized" do
        let(:Authorization) { nil }
        let(:body) { valid_params }

        run_test!
      end
    end
  end

  path "/api/v1/books/{id}" do
    parameter name: :id, in: :path, type: :string, required: true, description: "Book ID"

    get "Get book details" do
      tags "Books"
      description "Retrieve detailed information about a specific book. Available to all authenticated users."
      produces "application/vnd.api+json"
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: "JWT Bearer token"

      let!(:book) { create(:book, title: "Specific Book", author: "Specific Author") }

      response "200", "Book retrieved successfully" do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string, example: "books" },
                     attributes: {
                       type: :object,
                       properties: {
                         title: { type: :string },
                         author: { type: :string },
                         genre: { type: :string },
                         isbn: { type: :string },
                         total_copies: { type: :integer },
                         available_copies: { type: :integer }
                       }
                     }
                   }
                 },
                 meta: { type: :object }
               }

        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:id) { book.id }

        run_test! do |response|
          expect(json_response).to have_key("data")
          expect(json_response["data"]["type"]).to eq("books")
          expect(json_response["data"]["id"]).to eq(book.id.to_s)
          expect(json_response["data"]["attributes"]["title"]).to eq("Specific Book")
          expect(json_response["data"]["attributes"]["author"]).to eq("Specific Author")
        end
      end

      response "200", "Returns available_copies correctly with borrowings" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:id) { book.id }

        before { create(:borrowing, book: book) }

        run_test! do |response|
          expect(json_response["data"]["attributes"]["available_copies"]).to eq(book.available_copies)
        end
      end

      response "404", "Book not found" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:id) { 999999 }

        run_test! do |response|
          expect(json_response).to have_key("errors")
          expect(json_response["errors"].first["status"]).to eq("404")
        end
      end

      response "401", "Unauthorized" do
        let(:Authorization) { nil }
        let(:id) { book.id }

        run_test!
      end
    end

    patch "Update book" do
      tags "Books"
      description "Update book information. Only librarians can update books."
      consumes "application/json"
      produces "application/vnd.api+json"
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: "JWT Bearer token"

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          book: {
            type: :object,
            properties: {
              title: { type: :string },
              author: { type: :string },
              genre: { type: :string },
              isbn: { type: :string },
              total_copies: { type: :integer }
            }
          }
        }
      }

      let!(:book) { create(:book, title: "Original Title", author: "Original Author", total_copies: 5) }

      response "200", "Book updated successfully" do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string, example: "books" },
                     attributes: {
                       type: :object,
                       properties: {
                         title: { type: :string },
                         author: { type: :string },
                         genre: { type: :string },
                         isbn: { type: :string },
                         total_copies: { type: :integer },
                         available_copies: { type: :integer }
                       }
                     }
                   }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     message: { type: :string }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { book.id }
        let(:body) { { book: { title: "Updated Title" } } }

        run_test! do |response|
          expect(json_response["data"]["attributes"]["title"]).to eq("Updated Title")
          expect(json_response["data"]["attributes"]["author"]).to eq("Original Author")
          expect(json_response["meta"]["message"]).to eq("Book updated successfully.")
          expect(book.reload.title).to eq("Updated Title")
        end
      end

      response "200", "Updates multiple attributes" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { book.id }
        let(:body) { { book: { title: "New Title", author: "New Author", genre: "Science" } } }

        run_test! do |response|
          expect(json_response["data"]["attributes"]["title"]).to eq("New Title")
          expect(json_response["data"]["attributes"]["author"]).to eq("New Author")
          expect(json_response["data"]["attributes"]["genre"]).to eq("Science")
        end
      end

      response "403", "Forbidden - Only librarians can update books" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:id) { book.id }
        let(:body) { { book: { title: "Updated Title" } } }

        run_test! do
          expect(book.reload.title).to eq("Original Title")
        end
      end

      response "422", "Validation error - Empty title" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { book.id }
        let(:body) { { book: { title: "" } } }

        run_test!
      end

      response "422", "Validation error - Duplicate ISBN" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { book.id }

        let(:body) { { book: { isbn: other_book.isbn } } }
        let!(:other_book) { create(:book) }

        run_test!
      end

      response "404", "Book not found" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { 999999 }
        let(:body) { { book: { title: "Updated Title" } } }

        run_test!
      end

      response "401", "Unauthorized" do
        let(:Authorization) { nil }
        let(:id) { book.id }
        let(:body) { { book: { title: "Updated Title" } } }

        run_test!
      end
    end

    delete "Delete book" do
      tags "Books"
      description "Delete a book from the library. Only librarians can delete books. Books with active borrowings cannot be deleted."
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: "JWT Bearer token"

      let!(:book) { create(:book) }

      response "204", "Book deleted successfully" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { book.id }

        run_test! do
          expect(Book.find_by(id: book.id)).to be_nil
        end
      end

      response "204", "Deletes book with only returned borrowings" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { book.id }

        before { create(:borrowing, :returned, book: book) }

        run_test! do
          expect(Book.find_by(id: book.id)).to be_nil
        end
      end

      response "403", "Forbidden - Only librarians can delete books" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:id) { book.id }

        run_test! do
          expect(Book.find_by(id: book.id)).to be_present
        end
      end

      response "422", "Unprocessable entity - Book has active borrowings" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { book.id }

        before { create(:borrowing, book: book) }

        run_test! do |response|
          expect(json_response["errors"]).to be_present
          expect(json_response["errors"].first["detail"]).to include("active borrowings")
          expect(Book.find_by(id: book.id)).to be_present
        end
      end

      response "404", "Book not found" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { 999999 }

        run_test!
      end

      response "401", "Unauthorized" do
        let(:Authorization) { nil }
        let(:id) { book.id }

        run_test!
      end
    end
  end
end
