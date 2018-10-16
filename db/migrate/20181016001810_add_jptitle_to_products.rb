class AddJptitleToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :jp_title, :string
  end
end
