class AddRoiToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :roi, :float
  end
end
