class RenameColumnToFeeds < ActiveRecord::Migration[5.0]
  def change
    rename_column :feeds, :fullfillment_channel, :fulfillment_channel
  end
end
