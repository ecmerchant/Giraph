class AddUniqueToFeeds < ActiveRecord::Migration[5.0]
  def change
    execute <<-SQL
      ALTER TABLE feeds
        ADD CONSTRAINT for_upsert_feed UNIQUE ("sku", "user");
    SQL
  end
end
