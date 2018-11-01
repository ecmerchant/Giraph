class AddAsinUniqueToProducts < ActiveRecord::Migration[5.0]
  def change
    execute <<-SQL
      ALTER TABLE products
        ADD CONSTRAINT for_asin_upsert UNIQUE ("asin", "user", "listing_condition");
    SQL
  end
end
