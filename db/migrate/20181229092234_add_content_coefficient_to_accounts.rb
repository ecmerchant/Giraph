class AddContentCoefficientToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :content_coefficient, :float
  end
end
