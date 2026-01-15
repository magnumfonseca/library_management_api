# frozen_string_literal: true

class BorrowingSerializer
  include JSONAPI::Serializer

  set_type :borrowings

  attributes :borrowed_at, :due_date, :returned_at

  attribute :status do |borrowing|
    if borrowing.returned?
      "returned"
    elsif borrowing.overdue?
      "overdue"
    else
      "active"
    end
  end

  attribute :days_overdue do |borrowing|
    borrowing.days_overdue
  end

  attribute :book_id do |borrowing|
    borrowing.book_id
  end

  attribute :user_id do |borrowing|
    borrowing.user_id
  end

  attribute :book_title do |borrowing|
    borrowing.book&.title
  end
end
