class CreateAuthenticationRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :users, :email_address, unique: true

    create_table :sessions, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    create_table :api_tokens, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :token_digest, null: false

      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true
    add_index :api_tokens, %i[user_id name], unique: true
  end
end
