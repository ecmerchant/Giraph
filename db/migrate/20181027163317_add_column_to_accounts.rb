class AddColumnToAccounts < ActiveRecord::Migration[5.0]
  def change
    add_column :accounts, :handling_time, :integer
    add_column :accounts, :feed_submission_id, :string
    add_column :accounts, :feed_submit_at, :datetime
  end
end
