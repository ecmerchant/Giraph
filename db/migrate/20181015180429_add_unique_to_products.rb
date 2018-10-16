class AddUniqueToProducts < ActiveRecord::Migration[5.0]
  def change
    execute <<-SQL
      ALTER TABLE products
        ADD CONSTRAINT for_upsert UNIQUE ("sku", "user");
    SQL
  end
end
