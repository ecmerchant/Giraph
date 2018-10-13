class AddIndexToProducts < ActiveRecord::Migration[5.0]
  def change
    add_index  :products, [:user, :sku], unique: true
  end
end
