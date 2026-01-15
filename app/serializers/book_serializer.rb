# frozen_string_literal: true

class BookSerializer
  include JSONAPI::Serializer

  set_type :books

  attributes :title, :author, :genre, :isbn, :total_copies, :available_copies
end
