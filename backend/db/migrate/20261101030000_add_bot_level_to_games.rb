class AddBotLevelToGames < ActiveRecord::Migration[8.1]
  def change
    # Which bot plays the other seats: "easy" (SimpleBot) or "smart" (SmartBot).
    add_column :games, :bot_level, :string, null: false, default: 'smart'
  end
end
