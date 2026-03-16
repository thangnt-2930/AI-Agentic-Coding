# frozen_string_literal: true

class Transaction < ApplicationRecord
  TYPES = %w[income expense].freeze

  belongs_to :user
  belongs_to :category

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :transaction_type, inclusion: { in: TYPES }
  validates :transacted_on, presence: true

  scope :income, -> { where(transaction_type: 'income') }
  scope :expense, -> { where(transaction_type: 'expense') }
  scope :in_period, ->(start_date, end_date) { where(transacted_on: start_date..end_date) }
  scope :by_category, ->(cat_id) { where(category_id: cat_id) }
  scope :by_type, ->(type) { where(transaction_type: type) }
  scope :recent, -> { order(transacted_on: :desc, id: :desc) }
end
