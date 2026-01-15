# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Borrowings API", type: :request, openapi_spec: "v1/swagger.yaml" do
  let(:librarian) { create(:user, :librarian) }
  let(:member) { create(:user, :member) }

  def jwt_token_for(user)
    Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
  end

  path "/api/v1/borrowings" do
    get "List borrowings" do
      tags "Borrowings"
      description "Retrieve a list of borrowings. Librarians see all borrowings, members see only their own."
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

      response "200", "Borrowings retrieved successfully" do
        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :string },
                       type: { type: :string, example: "borrowings" },
                       attributes: {
                         type: :object,
                         properties: {
                           borrowed_at: { type: :string, format: "date-time" },
                           due_date: { type: :string, format: "date-time" },
                           returned_at: { type: :string, format: "date-time", nullable: true },
                           status: { type: :string, enum: %w[active overdue returned] },
                           days_overdue: { type: :integer },
                           book_id: { type: :integer },
                           user_id: { type: :integer },
                           book_title: { type: :string }
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

        before do
          create(:borrowing, user: member)
          create(:borrowing) # Different user's borrowing
        end

        run_test! do |response|
          expect(json_response).to have_key("data")
          expect(json_response["data"].size).to eq(1) # Member sees only their own
          expect(json_response["data"].first["type"]).to eq("borrowings")
          expect(json_response["meta"]["page"]).to include(
            "total" => 1,
            "number" => 1,
            "size" => 25
          )
          expect(json_response["links"]).to have_key("self")
        end
      end

      response "200", "Librarian sees all borrowings" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }

        before do
          create(:borrowing, user: member)
          create(:borrowing) # Different user's borrowing
        end

        run_test! do |response|
          expect(json_response["data"].size).to eq(2) # Librarian sees all
        end
      end

      response "200", "Returns borrowing attributes correctly" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let!(:book) { create(:book, title: "Test Book") }

        before do
          create(:borrowing, user: member, book: book)
        end

        run_test! do |response|
          borrowing_data = json_response["data"].first
          expect(borrowing_data["attributes"]["book_title"]).to eq("Test Book")
          expect(borrowing_data["attributes"]["status"]).to eq("active")
          expect(borrowing_data["attributes"]["days_overdue"]).to eq(0)
        end
      end

      response "200", "Returns paginated borrowings" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:per_page) { 5 }

        before { create_list(:borrowing, 12) }

        run_test! do |response|
          expect(json_response["data"].size).to eq(5)
          expect(json_response["meta"]["page"]["total"]).to eq(12)
          expect(json_response["meta"]["page"]["totalPages"]).to eq(3)
          expect(json_response["meta"]["page"]["number"]).to eq(1)
          expect(CGI.unescape(json_response["links"]["next"])).to include("page[number]=2")
        end
      end

      response "200", "Respects policy scope with pagination" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:per_page) { 10 }

        before do
          create_list(:borrowing, 15, user: member)
          create_list(:borrowing, 10) # Other users' borrowings
        end

        run_test! do |response|
          expect(json_response["data"].size).to eq(10)
          expect(json_response["meta"]["page"]["total"]).to eq(15) # Only member's borrowings
        end
      end

      response "200", "Pagination with JSON:API style params" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:"page[number]") { 2 }
        let(:"page[size]") { 3 }

        before { create_list(:borrowing, 10) }

        run_test! do |response|
          expect(json_response["data"].size).to eq(3)
          expect(json_response["meta"]["page"]["number"]).to eq(2)
          expect(CGI.unescape(json_response["links"]["prev"])).to include("page[number]=1")
        end
      end

      response "401", "Unauthorized - Missing or invalid token" do
        let(:Authorization) { nil }

        run_test!
      end
    end

    post "Borrow a book" do
      tags "Borrowings"
      description "Create a new borrowing. Only members can borrow books. The book must be available."
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
          borrowing: {
            type: :object,
            properties: {
              book_id: { type: :integer, description: "ID of the book to borrow" }
            },
            required: %w[book_id]
          }
        },
        required: %w[borrowing]
      }

      let(:book) { create(:book, total_copies: 5) }

      let(:valid_params) do
        {
          borrowing: {
            book_id: book.id
          }
        }
      end

      response "201", "Book borrowed successfully" do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string, example: "borrowings" },
                     attributes: {
                       type: :object,
                       properties: {
                         borrowed_at: { type: :string, format: "date-time" },
                         due_date: { type: :string, format: "date-time" },
                         returned_at: { type: :string, format: "date-time", nullable: true },
                         status: { type: :string },
                         days_overdue: { type: :integer },
                         book_id: { type: :integer },
                         user_id: { type: :integer },
                         book_title: { type: :string }
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

        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:body) { valid_params }

        run_test! do |response|
          expect(json_response).to have_key("data")
          expect(json_response["data"]["type"]).to eq("borrowings")
          expect(json_response["data"]["attributes"]["book_id"]).to eq(book.id)
          expect(json_response["data"]["attributes"]["user_id"]).to eq(member.id)
          expect(json_response["data"]["attributes"]["status"]).to eq("active")
          expect(json_response["meta"]["message"]).to eq("Book borrowed successfully.")
        end
      end

      response "201", "Creates a new borrowing record with correct due date" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:body) { valid_params }

        run_test! do
          expect(Borrowing.count).to eq(1)
          borrowing = Borrowing.last
          expect(borrowing.due_date.to_date).to eq(14.days.from_now.to_date)
        end
      end

      response "403", "Forbidden - Librarians cannot borrow books" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:body) { valid_params }

        run_test! do
          expect(Borrowing.count).to eq(0)
        end
      end

      response "422", "Validation error - Book not available" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:unavailable_book) { create(:book, total_copies: 1) }
        let(:body) { { borrowing: { book_id: unavailable_book.id } } }

        before do
          create(:borrowing, book: unavailable_book) # Use up the only copy
        end

        run_test! do |response|
          expect(json_response["errors"]).to be_present
        end
      end

      response "422", "Validation error - Member already has active borrowing for this book" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:body) { valid_params }

        before do
          create(:borrowing, user: member, book: book)
        end

        run_test! do |response|
          expect(json_response["errors"]).to be_present
        end
      end

      response "404", "Book not found" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:body) { { borrowing: { book_id: 999999 } } }

        run_test! do |response|
          expect(json_response["errors"]).to be_present
          expect(json_response["errors"].first["status"]).to eq("404")
        end
      end

      response "401", "Unauthorized" do
        let(:Authorization) { nil }
        let(:body) { valid_params }

        run_test!
      end
    end
  end

  path "/api/v1/borrowings/{id}" do
    parameter name: :id, in: :path, type: :string, required: true, description: "Borrowing ID"

    get "Get borrowing details" do
      tags "Borrowings"
      description "Retrieve detailed information about a specific borrowing. Members can only view their own borrowings."
      produces "application/vnd.api+json"
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: "JWT Bearer token"

      let!(:borrowing) { create(:borrowing, user: member) }

      response "200", "Borrowing retrieved successfully" do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string, example: "borrowings" },
                     attributes: {
                       type: :object,
                       properties: {
                         borrowed_at: { type: :string, format: "date-time" },
                         due_date: { type: :string, format: "date-time" },
                         returned_at: { type: :string, format: "date-time", nullable: true },
                         status: { type: :string },
                         days_overdue: { type: :integer },
                         book_id: { type: :integer },
                         user_id: { type: :integer },
                         book_title: { type: :string }
                       }
                     }
                   }
                 },
                 meta: { type: :object }
               }

        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:id) { borrowing.id }

        run_test! do |response|
          expect(json_response).to have_key("data")
          expect(json_response["data"]["type"]).to eq("borrowings")
          expect(json_response["data"]["id"]).to eq(borrowing.id.to_s)
        end
      end

      response "200", "Librarian can view any borrowing" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { borrowing.id }

        run_test!
      end

      response "403", "Forbidden - Member cannot view another user's borrowing" do
        let(:other_member) { create(:user, :member) }
        let!(:other_borrowing) { create(:borrowing, user: other_member) }
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:id) { other_borrowing.id }

        run_test!
      end

      response "404", "Borrowing not found" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:id) { 999999 }

        run_test! do |response|
          expect(json_response).to have_key("errors")
          expect(json_response["errors"].first["status"]).to eq("404")
        end
      end

      response "401", "Unauthorized" do
        let(:Authorization) { nil }
        let(:id) { borrowing.id }

        run_test!
      end
    end
  end

  path "/api/v1/borrowings/{id}/return" do
    parameter name: :id, in: :path, type: :string, required: true, description: "Borrowing ID"

    patch "Return a borrowed book" do
      tags "Borrowings"
      description "Mark a borrowing as returned. Only librarians can perform this action."
      produces "application/vnd.api+json"
      security [ { bearer_jwt: [] } ]

      parameter name: :Authorization,
                in: :header,
                type: :string,
                required: true,
                description: "JWT Bearer token"

      let!(:borrowing) { create(:borrowing, user: member) }

      response "200", "Book returned successfully" do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     id: { type: :string },
                     type: { type: :string, example: "borrowings" },
                     attributes: {
                       type: :object,
                       properties: {
                         borrowed_at: { type: :string, format: "date-time" },
                         due_date: { type: :string, format: "date-time" },
                         returned_at: { type: :string, format: "date-time" },
                         status: { type: :string, example: "returned" },
                         days_overdue: { type: :integer },
                         book_id: { type: :integer },
                         user_id: { type: :integer },
                         book_title: { type: :string }
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
        let(:id) { borrowing.id }

        run_test! do |response|
          expect(json_response).to have_key("data")
          expect(json_response["data"]["attributes"]["status"]).to eq("returned")
          expect(json_response["data"]["attributes"]["returned_at"]).to be_present
          expect(json_response["meta"]["message"]).to eq("Book returned successfully.")
          expect(borrowing.reload).to be_returned
        end
      end

      response "200", "Marks borrowing as returned in database" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { borrowing.id }

        run_test! do
          expect(borrowing.reload.returned_at).to be_present
        end
      end

      response "403", "Forbidden - Members cannot return books" do
        let(:Authorization) { "Bearer #{jwt_token_for(member)}" }
        let(:id) { borrowing.id }

        run_test! do
          expect(borrowing.reload.returned_at).to be_nil
        end
      end

      response "422", "Unprocessable entity - Book already returned" do
        let!(:returned_borrowing) { create(:borrowing, :returned, user: member) }
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { returned_borrowing.id }

        run_test! do |response|
          expect(json_response["errors"]).to be_present
        end
      end

      response "404", "Borrowing not found" do
        let(:Authorization) { "Bearer #{jwt_token_for(librarian)}" }
        let(:id) { 999999 }

        run_test!
      end

      response "401", "Unauthorized" do
        let(:Authorization) { nil }
        let(:id) { borrowing.id }

        run_test!
      end
    end
  end
end
