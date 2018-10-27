class CreateFeeds < ActiveRecord::Migration[5.0]
  def change
    create_table :feeds do |t|
      t.string :user
      t.string :submission_id
      t.string :sku
      t.float :price
      t.integer :quantity
      t.integer :handling_time
      t.string :fullfillment_channel

      t.timestamps
    end
  end
end
