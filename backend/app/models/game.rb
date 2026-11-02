class Game < ApplicationRecord
  validates :state, presence: true
  validates :human_index, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :bot_level, inclusion: { in: Games::BOT_LEVELS.keys }

  # A fresh engine built from the saved state; save changes back with #store.
  def engine
    BeanBazaar::Game.from_h(state)
  end

  # Also saves undo_states, which the move service changes alongside the state.
  def store(engine)
    update!(state: engine.to_h)
  end

  # Plays the bots in this game until the human has a move.
  def bot_runner(engine)
    BeanBazaar::BotRunner.new(engine, human_index: human_index, bot_class: Games::BOT_LEVELS.fetch(bot_level).constantize)
  end
end
