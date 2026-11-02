class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      # The whole engine state from BeanBazaar::Game#to_h; Rails only stores it.
      t.jsonb :state, null: false
      t.integer :human_index, null: false, default: 0

      t.timestamps
    end
  end
end
