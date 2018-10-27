class AddConditionToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :listing_condition, :string
    add_column :products, :shipping_type, :string
  end
end
