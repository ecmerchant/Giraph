class AddFilePathToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :csv_path, :string
    add_column :accounts, :csv_created_at, :datetime
  end
end
