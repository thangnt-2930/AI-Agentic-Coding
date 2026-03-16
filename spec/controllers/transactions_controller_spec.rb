# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TransactionsController, type: :controller do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:transaction) { create(:transaction, user: user, category: category) }

  before { sign_in user }

  describe 'GET #index' do
    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
    end
  end

  describe 'POST #create' do
    it 'creates a transaction' do
      expect do
        post :create,
             params: { transaction: { amount: 100, category_id: category.id, transaction_type: 'expense',
                                      transacted_on: Time.zone.today } }
      end.to change(Transaction, :count).by(1)
    end
  end
end
