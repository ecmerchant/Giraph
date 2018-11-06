class AddFeedUpdatedAtToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :feed_updated_at, :datetime
    add_column :accounts, :feed_status, :text
  end
end
