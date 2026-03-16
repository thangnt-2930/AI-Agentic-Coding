# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  it { is_expected.to have_many(:categories) }
  it { is_expected.to have_many(:transactions) }
  it { is_expected.to validate_presence_of(:email) }

  it 'validates uniqueness of email', :aggregate_failures do
    create(:user, email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
    user = build(:user, email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
    expect(user).not_to be_valid
    expect(user.errors[:email]).to include('has already been taken')
  end
end
