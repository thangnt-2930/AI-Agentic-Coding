# frozen_string_literal: true

class DashboardController < ApplicationController
  def show
    @categories = current_user.categories.ordered
  end
end
