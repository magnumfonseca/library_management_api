# frozen_string_literal: true

FactoryBot.define do
  factory :book do
    title { Faker::Book.title }
    author { Faker::Book.author }
    genre { Faker::Book.genre }
    isbn { Faker::Number.number(digits: 13) }
    total_copies { Faker::Number.between(from: 1, to: 99) }
  end
end
