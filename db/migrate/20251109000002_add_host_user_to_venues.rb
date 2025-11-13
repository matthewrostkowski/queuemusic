class AddHostUserToVenues < ActiveRecord::Migration[7.0]
  def change
    add_column :venues, :host_user_id, :bigint
    add_index :venues, :host_user_id
    add_foreign_key :venues, :users, column: :host_user_id
  end
end