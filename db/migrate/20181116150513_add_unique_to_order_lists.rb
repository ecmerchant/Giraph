class AddUniqueToOrderLists < ActiveRecord::Migration[5.0]
  def change
    execute <<-SQL
      ALTER TABLE order_lists
        ADD CONSTRAINT for_upsert_order UNIQUE ("sku", "order_id");
    SQL
  end
end
