# frozen_string_literal: true

require "rails_helper"

RSpec.describe Borrowings::ReturnService do
  let(:librarian) { create(:user, :librarian) }
  let(:member) { create(:user, :member) }
  let(:borrowing) { create(:borrowing, user: member) }

  describe "#call" do
    context "when borrowing is active" do
      subject(:service) { described_class.new(borrowing: borrowing, current_user: librarian) }

      it "returns a success response" do
        response = service.call

        expect(response).to be_success
      end

      it "marks the borrowing as returned" do
        service.call

        expect(borrowing.reload).to be_returned
      end

      it "sets returned_at to current time" do
        service.call

        expect(borrowing.reload.returned_at).to be_within(1.minute).of(Time.current)
      end

      it "returns the updated borrowing" do
        response = service.call

        expect(response.data).to be_a(Borrowing)
        expect(response.data.returned_at).to be_present
      end

      it "includes success message in meta" do
        response = service.call

        expect(response.meta[:message]).to eq("Book returned successfully.")
      end
    end

    context "when borrowing is already returned (422 Unprocessable Entity)" do
      let(:returned_borrowing) { create(:borrowing, :returned, user: member) }
      subject(:service) { described_class.new(borrowing: returned_borrowing, current_user: librarian) }

      it "returns failure response" do
        response = service.call

        expect(response).to be_failure
        expect(response.http_status).to eq(:unprocessable_content)
      end

      it "returns error message" do
        response = service.call

        expect(response.errors).to include("Borrowing has already been returned")
      end

      it "does not modify the borrowing" do
        original_returned_at = returned_borrowing.returned_at
        service.call

        expect(returned_borrowing.reload.returned_at).to eq(original_returned_at)
      end
    end

    context "when returning an overdue borrowing" do
      let(:overdue_borrowing) { create(:borrowing, :overdue, user: member) }
      subject(:service) { described_class.new(borrowing: overdue_borrowing, current_user: librarian) }

      it "still returns successfully" do
        response = service.call

        expect(response).to be_success
      end

      it "marks the overdue borrowing as returned" do
        service.call

        expect(overdue_borrowing.reload).to be_returned
      end
    end
  end
end
