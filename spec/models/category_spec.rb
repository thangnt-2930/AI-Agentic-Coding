# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Category, type: :model do
  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_many(:transactions).dependent(:restrict_with_error) }
  it { is_expected.to validate_presence_of(:name) }

  # rubocop:disable RSpec/IndexedLet
  describe 'scopes' do
    let(:user) { create(:user) }
    let!(:category1) { create(:category, user: user, name: 'Food') }
    let!(:category2) { create(:category, user: user, name: 'Transport') }

    it 'returns categories for user' do
      expect(described_class.where(user: user)).to include(category1, category2)
    end
  end
  # rubocop:enable RSpec/IndexedLet
end
