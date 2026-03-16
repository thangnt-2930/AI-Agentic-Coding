# frozen_string_literal: true

FactoryBot.define do
  factory :category do
    user { nil }
    name { 'MyString' }
  end
end
