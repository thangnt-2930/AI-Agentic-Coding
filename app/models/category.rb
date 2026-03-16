# frozen_string_literal: true

class Category < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }

  scope :for_user, ->(user) { where(user: user) }
  scope :ordered, -> { order(:name) }
end
