# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    role { :member }

    trait :member do
      role { :member }
    end

    trait :librarian do
      role { :librarian }
    end
  end
end
