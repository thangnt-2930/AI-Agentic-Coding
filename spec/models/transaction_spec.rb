# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Transaction, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:category) }
  it { is_expected.to validate_presence_of(:amount) }
  it { is_expected.to validate_numericality_of(:amount) }
  it { is_expected.to validate_inclusion_of(:transaction_type).in_array(%w[income expense]) }

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:category) { create(:category, user: user) }
    let!(:income) do
      create(:transaction, user: user, category: category, transaction_type: 'income', amount: 100,
                           transacted_on: Time.zone.today)
    end
    let!(:expense) do
      create(:transaction, user: user, category: category, transaction_type: 'expense', amount: 50,
                           transacted_on: Time.zone.today)
    end

    it 'returns income transactions', :aggregate_failures do
      expect(described_class.income).to include(income)
      expect(described_class.income).not_to include(expense)
    end

    it 'returns expense transactions', :aggregate_failures do
      expect(described_class.expense).to include(expense)
      expect(described_class.expense).not_to include(income)
    end

    it 'returns transactions in period', :aggregate_failures do
      expect(described_class.in_period(Time.zone.today, Time.zone.today)).to include(income, expense)
    end
  end
end
