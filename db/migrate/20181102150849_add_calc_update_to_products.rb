class AddCalcUpdateToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :calc_updated_at, :datetime
  end
end
