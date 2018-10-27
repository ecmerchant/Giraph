class AddValidityToProducts < ActiveRecord::Migration[5.0]
  def change
    add_column :products, :validity, :boolean
  end
end
