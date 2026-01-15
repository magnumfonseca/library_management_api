# frozen_string_literal: true

FactoryBot.define do
  factory :borrowing do
    association :user, factory: [ :user, :member ]
    association :book
    borrowed_at { Time.current }
    due_date { 14.days.from_now }
    returned_at { nil }

    trait :returned do
      returned_at { Time.current }
    end

    trait :overdue do
      due_date { 3.days.ago }
    end

    trait :due_today do
      borrowed_at { 14.days.ago }
      due_date { Time.current.end_of_day }
    end
  end
end
