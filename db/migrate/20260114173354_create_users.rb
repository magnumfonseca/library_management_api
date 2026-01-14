class CreateUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Custom fields
      t.string :name,               null: false
      t.string :role,               null: false, default: "member"

      ## JWT token tracking (for revocation)
      t.string :jti,                null: false

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :jti,                  unique: true
  end
end
