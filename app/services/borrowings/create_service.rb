# frozen_string_literal: true

module Borrowings
  class CreateService
    def initialize(book_id:, current_user:)
      @book_id = book_id
      @current_user = current_user
    end

    def call
      ActiveRecord::Base.transaction do
        # Lock the book row to serialize concurrent borrow attempts for the same book
        book = Book.lock.find_by(id: @book_id)

        return Response.failure("Book not found", http_status: :not_found) unless book

        unless book.available?
          return Response.failure("Book is not available for borrowing", http_status: :unprocessable_content)
        end

        if book.borrowed_by?(@current_user)
          return Response.failure("You already have an active borrowing for this book", http_status: :unprocessable_content)
        end

        borrowing = Borrowing.new(user: @current_user, book: book)

        if borrowing.save
          Response.success(borrowing, meta: { message: "Book borrowed successfully." })
        else
          Response.failure(borrowing.errors.full_messages)
        end
      end
    end
  end
end
