# frozen_string_literal: true

class DashboardsController < ApplicationController
  # rubocop:disable Metrics/AbcSize
  def index
    @period = params[:period] || 'this_month'
    start_date, end_date = period_range(@period)
    scope = current_user.transactions.in_period(start_date, end_date)
    @total_income = scope.income.sum(:amount)
    @total_expense = scope.expense.sum(:amount)
    @net_balance = @total_income - @total_expense
    @category_breakdown = scope.expense.joins(:category)
                               .group('categories.name')
                               .order('sum_amount DESC')
                               .sum(:amount)
  end
  # rubocop:enable Metrics/AbcSize

  private

  def period_range(period)
    case period
    when 'today'
      [Date.current, Date.current]
    when 'this_week'
      [Date.current.beginning_of_week, Date.current.end_of_week]
    else
      [Date.current.beginning_of_month, Date.current.end_of_month]
    end
  end
end
