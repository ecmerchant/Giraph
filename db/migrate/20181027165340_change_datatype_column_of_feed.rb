class ChangeDatatypeColumnOfFeed < ActiveRecord::Migration[5.0]
  def change
    change_column :feeds, :price, :string
    change_column :feeds, :quantity, :string
    change_column :feeds, :handling_time, :string
  end
end
