# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CategoriesController, type: :controller do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }

  before { sign_in user }

  describe 'GET #index' do
    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @categories' do
      category
      get :index
      expect(assigns(:categories)).to include(category)
    end
  end

  describe 'POST #create' do
    it 'creates a category' do
      expect do
        post :create, params: { category: { name: 'Food' } }
      end.to change(Category, :count).by(1)
    end
  end
end
