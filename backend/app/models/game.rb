class Game < ApplicationRecord
  validates :state, presence: true
  validates :human_index, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # A fresh engine built from the saved state; save changes back with #store.
  def engine
    BeanBazaar::Game.from_h(state)
  end

  def store(engine)
    update!(state: engine.to_h)
  end
end
