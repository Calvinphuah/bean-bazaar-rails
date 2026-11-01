class Games
  # Seat the human always takes; the bots sit after them.
  HUMAN_INDEX = 0

  # How many bots a human can play against.
  BOT_COUNTS = 2..4
  DEFAULT_BOT_COUNT = 3

  # Bot seat names, in seating order.
  BOT_NAMES = %w[Pinto Lima Fava Mung].freeze

  # Bot difficulty, mapped to the bot class that plays it.
  BOT_LEVELS = {
    'easy' => 'BeanBazaar::Bots::SimpleBot',
    'smart' => 'BeanBazaar::Bots::SmartBot',
  }.freeze
  DEFAULT_BOT_LEVEL = 'smart'.freeze

  # Moves only the active player can make; harvesting, buying a field and
  # planting pending cards are allowed on any turn.
  ACTIVE_PLAYER_MOVES = %w[plant_from_hand flip_cards trade end_trading].freeze

  # Answers to an offer a bot made to the human, allowed on the bot's turn.
  OFFER_ANSWERS = %w[accept_offer decline_offer].freeze

  # Moves the human can take back: they reveal no cards and no bot reacts to them.
  UNDOABLE_MOVES = %w[plant_from_hand harvest plant_pending buy_third_field].freeze
  # Log events those moves may add; any other new event (a flip, a trade, a new turn)
  # means something happened that can't be taken back.
  UNDOABLE_EVENTS = %w[plant harvest buy_field].freeze
  # How many moves back the human can go.
  MAX_UNDOS = 20
end
