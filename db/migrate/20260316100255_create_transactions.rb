# frozen_string_literal: true

class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.decimal :amount, null: false, precision: 15, scale: 2
      t.string :transaction_type, null: false
      t.date :transacted_on, null: false
      t.text :note
      t.timestamps
    end

    # Indexes for user_id and category_id are already added by t.references
    add_index :transactions, :transacted_on
    add_index :transactions, %i[user_id transacted_on]
  end
end
