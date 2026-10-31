class Games
  # Seat the human always takes; the bots sit after them.
  HUMAN_INDEX = 0

  # How many bots a human can play against.
  BOT_COUNTS = 2..4
  DEFAULT_BOT_COUNT = 3

  # Bot seat names, in seating order.
  BOT_NAMES = %w[Pinto Lima Fava Mung].freeze

  # Moves only the active player can make; harvesting, buying a field and
  # planting pending cards are allowed on any turn.
  ACTIVE_PLAYER_MOVES = %w[plant_from_hand flip_cards trade end_trading].freeze
end
