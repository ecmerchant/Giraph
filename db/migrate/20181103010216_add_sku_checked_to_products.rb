class AddSkuCheckedToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :sku_checked, :boolean
  end
end
