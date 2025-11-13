class AddHostFieldsToQueueSessions < ActiveRecord::Migration[7.0]
  def change
    add_column :queue_sessions, :join_code, :string, null: false unless column_exists?(:queue_sessions, :join_code)
    add_column :queue_sessions, :status, :string, default: 'active', null: false unless column_exists?(:queue_sessions, :status)
    add_column :queue_sessions, :started_at, :datetime unless column_exists?(:queue_sessions, :started_at)
    add_column :queue_sessions, :ended_at, :datetime unless column_exists?(:queue_sessions, :ended_at)
    add_column :queue_sessions, :code_expires_at, :datetime unless column_exists?(:queue_sessions, :code_expires_at)
    
    add_index :queue_sessions, :join_code unless index_exists?(:queue_sessions, :join_code)
    add_index :queue_sessions, [:venue_id, :status] unless index_exists?(:queue_sessions, [:venue_id, :status])
  end
end