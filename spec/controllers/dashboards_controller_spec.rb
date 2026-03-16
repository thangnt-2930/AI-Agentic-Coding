# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardsController, type: :controller do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let!(:transaction) do
    create(:transaction, user: user, category: category, amount: 100, transaction_type: 'expense',
                         transacted_on: Time.zone.today)
  end

  before { sign_in user }

  describe 'GET #index' do
    it 'returns a successful response', :aggregate_failures do
      get :index
      expect(response).to be_successful
      expect(assigns(:transactions)).to eq([transaction])
    end

    it 'assigns dashboard variables', :aggregate_failures do
      get :index
      expect(assigns(:total_income)).to eq(0)
      expect(assigns(:total_expense)).to eq(100)
      expect(assigns(:net_balance)).to eq(-100)
      expect(assigns(:category_breakdown)).to include(category.name => 100)
    end
  end
end
