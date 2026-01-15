# frozen_string_literal: true

module Books
  class DeleteService
    def initialize(book:, current_user:)
      @book = book
      @current_user = current_user
    end

    def call
      return active_borrowings_response if @book.borrowings.active.exists?

      @book.destroy!
      Response.success(nil, meta: { message: "Book deleted successfully." })
    end

    private

    def active_borrowings_response
      Response.failure("Cannot delete book with active borrowings.")
    end
  end
end
