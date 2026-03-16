# frozen_string_literal: true

FactoryBot.define do
  factory :transaction do
    association :user
    association :category
    amount { 100_000 }
    transaction_type { 'income' }
    transacted_on { Date.current }
    note { 'Sample transaction' }

    trait :income do
      transaction_type { 'income' }
    end

    trait :expense do
      transaction_type { 'expense' }
    end
  end
end
