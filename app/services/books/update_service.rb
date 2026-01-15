# frozen_string_literal: true

module Books
  class UpdateService
    def initialize(book:, params:, current_user:)
      @book = book
      @params = params
      @current_user = current_user
    end

    def call
      if @book.update(book_params)
        Response.success(@book, meta: { message: "Book updated successfully." })
      else
        Response.failure(@book.errors.full_messages)
      end
    end

    private

    def book_params
      @params.slice(:title, :author, :genre, :isbn, :total_copies)
    end
  end
end
