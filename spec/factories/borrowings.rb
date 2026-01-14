# frozen_string_literal: true

FactoryBot.define do
  factory :borrowing do
    association :user
    association :book
    returned_at { nil }
  end
end
