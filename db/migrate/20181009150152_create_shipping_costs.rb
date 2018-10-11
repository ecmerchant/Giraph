class CreateShippingCosts < ActiveRecord::Migration[5.0]
  def change
    create_table :shipping_costs do |t|
      t.string :user
      t.string :name
      t.float :weight
      t.float :cost

      t.timestamps
    end
  end
end
