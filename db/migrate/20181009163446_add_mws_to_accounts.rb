class AddMwsToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :us_seller_id1, :string
    add_column :accounts, :us_aws_access_key_id1, :string
    add_column :accounts, :us_secret_key1, :string
    add_column :accounts, :us_seller_id2, :string
    add_column :accounts, :us_aws_access_key_id2, :string
    add_column :accounts, :us_secret_key2, :string
  end
end
