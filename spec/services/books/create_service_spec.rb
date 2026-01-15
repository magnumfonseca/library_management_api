# frozen_string_literal: true

require "rails_helper"

RSpec.describe Books::CreateService do
  let(:librarian) { create(:user, :librarian) }
  let(:member) { create(:user, :member) }
  let(:valid_params) do
    {
      title: "Test Book",
      author: "Test Author",
      genre: "Fiction",
      isbn: "9781234567890",
      total_copies: 5
    }
  end

  describe "#call" do
    context "when user is a librarian with valid params" do
      subject(:service) { described_class.new(params: valid_params, current_user: librarian) }

      it "returns a success response" do
        response = service.call

        expect(response).to be_success
      end

      it "creates a book" do
        expect { service.call }.to change(Book, :count).by(1)
      end

      it "returns the created book" do
        response = service.call

        expect(response.data).to be_a(Book)
        expect(response.data.title).to eq("Test Book")
        expect(response.data.author).to eq("Test Author")
        expect(response.data.genre).to eq("Fiction")
        expect(response.data.isbn).to eq("9781234567890")
        expect(response.data.total_copies).to eq(5)
      end

      it "includes success message in meta" do
        response = service.call

        expect(response.meta[:message]).to eq("Book created successfully.")
      end
    end



    context "with invalid params (422 Unprocessable Entity)" do
      context "when title is missing" do
        let(:invalid_params) { valid_params.merge(title: "") }
        subject(:service) { described_class.new(params: invalid_params, current_user: librarian) }

        it "returns failure response" do
          response = service.call

          expect(response).to be_failure
          expect(response.http_status).to eq(:unprocessable_content)
        end

        it "returns validation errors" do
          response = service.call

          expect(response.errors).to include("Title can't be blank")
        end

        it "does not create a book" do
          expect { service.call }.not_to change(Book, :count)
        end
      end

      context "when ISBN is duplicate" do
        before { create(:book, isbn: "9781234567890") }
        subject(:service) { described_class.new(params: valid_params, current_user: librarian) }

        it "returns failure response" do
          response = service.call

          expect(response).to be_failure
          expect(response.http_status).to eq(:unprocessable_content)
        end

        it "returns validation errors" do
          response = service.call

          expect(response.errors).to include("Isbn has already been taken")
        end
      end

      context "when total_copies is invalid" do
        let(:invalid_params) { valid_params.merge(total_copies: 0) }
        subject(:service) { described_class.new(params: invalid_params, current_user: librarian) }

        it "returns failure response" do
          response = service.call

          expect(response).to be_failure
        end
      end
    end
  end
end
