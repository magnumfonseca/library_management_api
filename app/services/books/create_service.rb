# frozen_string_literal: true

module Books
  class CreateService
    def initialize(params:, current_user:)
      @params = params
      @current_user = current_user
    end

    def call
      book = Book.new(book_params)

      if book.save
        Response.success(book, meta: { message: "Book created successfully." })
      else
        Response.failure(book.errors.full_messages)
      end
    end

    private

    def book_params
      @params.slice(:title, :author, :genre, :isbn, :total_copies)
    end
  end
end
