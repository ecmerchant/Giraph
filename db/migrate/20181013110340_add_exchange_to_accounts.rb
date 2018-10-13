class AddExchangeToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :exchange_rate, :float
    add_column :accounts, :calc_ex_rate, :float
  end
end
