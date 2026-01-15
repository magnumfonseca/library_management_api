# frozen_string_literal: true

require "rails_helper"

RSpec.describe Borrowings::CreateService do
  let(:member) { create(:user, :member) }
  let(:book) { create(:book, total_copies: 5) }

  describe "#call" do
    context "when book is available and member has no active borrowing" do
      subject(:service) { described_class.new(book_id: book.id, current_user: member) }

      it "returns a success response" do
        response = service.call

        expect(response).to be_success
      end

      it "creates a borrowing record" do
        expect { service.call }.to change(Borrowing, :count).by(1)
      end

      it "returns the created borrowing" do
        response = service.call

        expect(response.data).to be_a(Borrowing)
        expect(response.data.user).to eq(member)
        expect(response.data.book).to eq(book)
      end

      it "sets borrowed_at to current time" do
        response = service.call

        expect(response.data.borrowed_at).to be_within(1.minute).of(Time.current)
      end

      it "sets due_date to 14 days from now" do
        response = service.call

        expect(response.data.due_date.to_date).to eq(14.days.from_now.to_date)
      end

      it "includes success message in meta" do
        response = service.call

        expect(response.meta[:message]).to eq("Book borrowed successfully.")
      end
    end

    context "when book is not found (404 Not Found)" do
      subject(:service) { described_class.new(book_id: 999999, current_user: member) }

      it "returns failure response" do
        response = service.call

        expect(response).to be_failure
        expect(response.http_status).to eq(:not_found)
      end

      it "returns not found error message" do
        response = service.call

        expect(response.errors).to include("Book not found")
      end

      it "does not create a borrowing" do
        expect { service.call }.not_to change(Borrowing, :count)
      end
    end

    context "when book is not available (422 Unprocessable Entity)" do
      let(:unavailable_book) { create(:book, total_copies: 1) }
      subject(:service) { described_class.new(book_id: unavailable_book.id, current_user: member) }

      before do
        create(:borrowing, book: unavailable_book) # Use up the only copy
      end

      it "returns failure response" do
        response = service.call

        expect(response).to be_failure
        expect(response.http_status).to eq(:unprocessable_content)
      end

      it "returns validation errors" do
        response = service.call

        expect(response.errors).to include("Book is not available for borrowing")
      end

      it "does not create a borrowing" do
        expect { service.call }.not_to change(Borrowing, :count)
      end
    end

    context "when member already has active borrowing for this book (422 Unprocessable Entity)" do
      subject(:service) { described_class.new(book_id: book.id, current_user: member) }

      before do
        create(:borrowing, user: member, book: book)
      end

      it "returns failure response" do
        response = service.call

        expect(response).to be_failure
        expect(response.http_status).to eq(:unprocessable_content)
      end

      it "returns validation errors" do
        response = service.call

        expect(response.errors.join).to include("You already have an active borrowing for this book")
      end

      it "does not create another borrowing" do
        expect { service.call }.not_to change(Borrowing, :count)
      end
    end

    context "when member returns a previously borrowed book and borrows again" do
      subject(:service) { described_class.new(book_id: book.id, current_user: member) }

      before do
        create(:borrowing, :returned, user: member, book: book)
      end

      it "allows borrowing the same book again" do
        response = service.call

        expect(response).to be_success
        expect(response.data).to be_a(Borrowing)
      end
    end

    context "when multiple members attempt to borrow the last copy concurrently" do
      let(:book) { create(:book, total_copies: 1) }
      let(:member1) { create(:user, :member) }
      let(:member2) { create(:user, :member) }

      it "only allows one borrowing to succeed" do
        responses = []
        threads = []

        [member1, member2].each do |m|
          threads << Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              responses << described_class.new(book_id: book.id, current_user: m).call
            end
          end
        end

        threads.each(&:join)

        expect(Borrowing.where(book: book).count).to eq(1)
        expect(responses.count(&:success?)).to eq(1)
        expect(responses.count(&:failure?)).to eq(1)
      end
    end
  end
end
