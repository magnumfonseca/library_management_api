class CreateInvitations < ActiveRecord::Migration[7.2]
  def change
    create_table :invitations do |t|
      t.string :email, null: false
      t.string :token, null: false
      t.string :role, null: false, default: "librarian"
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.datetime :accepted_at
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, :email
  end
end
