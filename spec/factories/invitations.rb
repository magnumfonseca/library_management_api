# frozen_string_literal: true

FactoryBot.define do
  factory :invitation do
    email { Faker::Internet.unique.email }
    role { "librarian" }
    association :invited_by, factory: [ :user, :librarian ]

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :accepted do
      accepted_at { 1.hour.ago }
    end
  end
end
