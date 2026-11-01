class AddUndoStatesToGames < ActiveRecord::Migration[8.1]
  def change
    # Engine states before each of the human's undoable moves, newest last.
    add_column :games, :undo_states, :jsonb, null: false, default: []
  end
end
