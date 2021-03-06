class CreateStores < ActiveRecord::Migration[5.0]
  def change
    create_table :stores do |t|
      t.string :store_hash
      t.string :access_token
      t.text :scope
      t.string :username
      t.string :email

      t.timestamps
    end
  end
end
