# frozen_string_literal: true

require "rails_helper"

RSpec.describe Books::DeleteService do
  let(:librarian) { create(:user, :librarian) }
  let(:member) { create(:user, :member) }
  let!(:book) { create(:book) }

  describe "#call" do
    context "when user is a librarian with no active borrowings" do
      subject(:service) { described_class.new(book: book, current_user: librarian) }

      it "returns a success response" do
        response = service.call

        expect(response).to be_success
      end

      it "deletes the book" do
        expect { service.call }.to change(Book, :count).by(-1)
      end

      it "includes success message in meta" do
        response = service.call

        expect(response.meta[:message]).to eq("Book deleted successfully.")
      end
    end



    context "when book has active borrowings (422 Unprocessable Entity)" do
      before { create(:borrowing, book: book) }
      subject(:service) { described_class.new(book: book, current_user: librarian) }

      it "returns failure response" do
        response = service.call

        expect(response).to be_failure
        expect(response.http_status).to eq(:unprocessable_content)
      end

      it "returns appropriate error message" do
        response = service.call

        expect(response.errors).to include("Cannot delete book with active borrowings.")
      end

      it "does not delete the book" do
        expect { service.call }.not_to change(Book, :count)
      end
    end

    context "when book has only returned borrowings" do
      before { create(:borrowing, :returned, book: book) }
      subject(:service) { described_class.new(book: book, current_user: librarian) }

      it "returns a success response" do
        response = service.call

        expect(response).to be_success
      end

      it "deletes the book" do
        expect { service.call }.to change(Book, :count).by(-1)
      end
    end
  end
end
