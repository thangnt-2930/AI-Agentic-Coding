require 'rails_helper'

RSpec.describe Category, type: :model do
  describe 'associations' do
    pending 'should belong_to(:user)'
    pending 'should have_many(:transactions).dependent(:restrict_with_error)'
  end

  describe 'validations' do
    pending 'should validate_presence_of(:name)'
    pending 'should validate_uniqueness_of(:name).scoped_to(:user_id).case_insensitive'
  end

  describe 'scopes' do
    pending 'for_user returns only categories for the given user'
    pending 'ordered returns categories sorted by name'
  end
end
