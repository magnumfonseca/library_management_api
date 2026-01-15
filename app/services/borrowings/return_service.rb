# frozen_string_literal: true

module Borrowings
  class ReturnService
    def initialize(borrowing:, current_user:)
      @borrowing = borrowing
      @current_user = current_user
    end

    def call
      if @borrowing.returned?
        return Response.failure("Borrowing has already been returned")
      end

      @borrowing.mark_as_returned!
      Response.success(@borrowing, meta: { message: "Book returned successfully." })
    rescue StandardError => e
      Response.failure(e.message)
    end
  end
end
