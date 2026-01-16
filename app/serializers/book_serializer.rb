# frozen_string_literal: true

class BookSerializer
  include JSONAPI::Serializer

  set_type :books

  attributes :title, :author, :genre, :isbn, :total_copies, :available_copies

  attribute :borrowed_by_current_user do |book, params|
    current_user = params[:current_user]
    next false unless current_user&.member?

    # Use preloaded association to check if user has active borrowing
    # This avoids N+1 queries when books are loaded with .includes(:borrowings)
    if book.association(:borrowings).loaded?
      book.borrowings.any? { |b| b.user_id == current_user.id && b.returned_at.nil? }
    else
      # Fallback for create/update responses where borrowings aren't preloaded
      book.borrowed_by?(current_user)
    end
  end
end
