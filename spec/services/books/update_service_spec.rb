# frozen_string_literal: true

require "rails_helper"

RSpec.describe Books::UpdateService do
  let(:librarian) { create(:user, :librarian) }
  let(:member) { create(:user, :member) }
  let!(:book) { create(:book, title: "Original Title", author: "Original Author", total_copies: 5) }
  let(:update_params) { { title: "Updated Title" } }

  describe "#call" do
    context "when user is a librarian with valid params" do
      subject(:service) { described_class.new(book: book, params: update_params, current_user: librarian) }

      it "returns a success response" do
        response = service.call

        expect(response).to be_success
      end

      it "updates the book" do
        service.call

        expect(book.reload.title).to eq("Updated Title")
      end

      it "returns the updated book" do
        response = service.call

        expect(response.data).to eq(book)
        expect(response.data.title).to eq("Updated Title")
      end

      it "includes success message in meta" do
        response = service.call

        expect(response.meta[:message]).to eq("Book updated successfully.")
      end

      it "can update multiple attributes" do
        service = described_class.new(
          book: book,
          params: { title: "New Title", author: "New Author", genre: "Science" },
          current_user: librarian
        )

        response = service.call

        expect(response).to be_success
        expect(book.reload.title).to eq("New Title")
        expect(book.author).to eq("New Author")
        expect(book.genre).to eq("Science")
      end
    end



    context "with invalid params (422 Unprocessable Entity)" do
      context "when title is empty" do
        let(:invalid_params) { { title: "" } }
        subject(:service) { described_class.new(book: book, params: invalid_params, current_user: librarian) }

        it "returns failure response" do
          response = service.call

          expect(response).to be_failure
          expect(response.http_status).to eq(:unprocessable_content)
        end

        it "returns validation errors" do
          response = service.call

          expect(response.errors).to include("Title can't be blank")
        end

        it "does not update the book" do
          service.call

          expect(book.reload.title).to eq("Original Title")
        end
      end

      context "when ISBN is duplicate" do
        let!(:other_book) { create(:book) }
        subject(:service) { described_class.new(book: book, params: { isbn: other_book.isbn }, current_user: librarian) }

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
    end
  end
end
