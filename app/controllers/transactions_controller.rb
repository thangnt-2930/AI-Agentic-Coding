# frozen_string_literal: true

class TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[edit update destroy]

  def index
    @transactions = filtered_transactions(params)
    @categories = current_user.categories.ordered
  end

  def new
    @transaction = current_user.transactions.new
    @categories = current_user.categories.ordered
  end

  def create
    @transaction = current_user.transactions.new(transaction_params)
    @categories = current_user.categories.ordered
    if @transaction.save
      redirect_to transactions_path, notice: 'Transaction created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = current_user.categories.ordered
  end

  def update
    @categories = current_user.categories.ordered
    if @transaction.update(transaction_params)
      redirect_to transactions_path, notice: 'Transaction updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction.destroy
    redirect_to transactions_path, notice: 'Transaction deleted.'
  end

  private

  def base_transactions
    current_user.transactions.includes(:category).recent
  end

  def filter_by_period(scope, params)
    return scope if params[:start_date].blank? || params[:end_date].blank?

    scope.in_period(params[:start_date], params[:end_date])
  end

  def filter_by_category(scope, params)
    return scope if params[:category_id].blank?

    scope.by_category(params[:category_id])
  end

  def filter_by_type(scope, params)
    return scope if params[:transaction_type].blank?

    scope.by_type(params[:transaction_type])
  end

  def filtered_transactions(params)
    filter_by_type(
      filter_by_category(
        filter_by_period(base_transactions, params), params
      ), params
    )
  end

  def set_transaction
    @transaction = current_user.transactions.find(params[:id])
  end

  def transaction_params
    params.require(:transaction).permit(:amount, :transaction_type, :transacted_on, :category_id, :note)
  end
end
