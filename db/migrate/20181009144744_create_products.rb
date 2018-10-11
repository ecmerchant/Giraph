class CreateProducts < ActiveRecord::Migration[5.0]
  def change
    create_table :products do |t|
      t.string :asin
      t.string :sku
      t.float :jp_price
      t.float :jp_shipping
      t.float :jp_point
      t.float :cost_price
      t.float :size_length
      t.float :size_width
      t.float :size_height
      t.float :size_weight
      t.float :shipping_weight
      t.float :us_price
      t.float :us_shipping
      t.float :us_point
      t.float :max_roi
      t.float :us_listing_price
      t.float :referral_fee
      t.float :referral_fee_rate
      t.float :variable_closing_fee
      t.float :listing_shipping
      t.float :delivery_fee
      t.float :exchange_rate
      t.float :payoneer_fee
      t.float :calc_ex_rate
      t.float :profit
      t.float :minimum_listing_price

      t.timestamps
    end
  end
end
