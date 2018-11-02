class AddUpdatesToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :info_updated_at, :datetime
    add_column :products, :jp_price_updated_at, :datetime
    add_column :products, :us_price_updated_at, :datetime
    add_column :products, :revised, :boolean
  end
end
