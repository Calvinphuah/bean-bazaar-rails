class AddBotLevelToGames < ActiveRecord::Migration[8.1]
  def change
    # Which bot plays the other seats: "easy", "normal" or "smart".
    add_column :games, :bot_level, :string, null: false, default: 'normal'
  end
end
