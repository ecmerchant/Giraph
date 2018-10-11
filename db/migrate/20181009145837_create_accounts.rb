class CreateAccounts < ActiveRecord::Migration[5.0]
  def change
    create_table :accounts do |t|
      t.string :user
      t.string :seller_id
      t.string :mws_auth_token
      t.string :aws_access_key_id
      t.string :secret_key
      t.float :shipping_weight
      t.float :max_roi
      t.float :listing_shipping
      t.float :delivery_fee
      t.float :payoneer_fee

      t.timestamps
    end
  end
end
