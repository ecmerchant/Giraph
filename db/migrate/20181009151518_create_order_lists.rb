class CreateOrderLists < ActiveRecord::Migration[5.0]
  def change
    create_table :order_lists do |t|
      t.string :user
      t.datetime :order_date
      t.string :order_id
      t.string :sku
      t.float :sales
      t.float :amazon_fee
      t.float :ex_rate
      t.float :cost_price
      t.float :listing_shipping
      t.float :profit
      t.float :roi

      t.timestamps
    end
  end
end
