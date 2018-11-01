class AddAsinUniqueToProducts < ActiveRecord::Migration[5.0]
  def change
    execute <<-SQL
      ALTER TABLE products
        ADD CONSTRAINT for_asin_upsert UNIQUE ("user", "asin", "listing_condition", "shipping_type");
    SQL
  end
end
