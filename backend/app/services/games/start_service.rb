module Games
  # Deals a new game for the human (always seat 0) against 2 to 4 bots, then
  # lets the bots play until it is the human's move.
  class StartService
    BOT_COUNTS = 2..4
    BOT_NAMES = [ "Pinto", "Lima", "Fava", "Mung" ].freeze
    HUMAN_INDEX = 0

    def initialize(bot_count:, random: Random.new)
      @bot_count = bot_count
      @random = random
    end

    def call
      raise BeanBazaar::IllegalMove, "Choose #{BOT_COUNTS.min} to #{BOT_COUNTS.max} bots" if !BOT_COUNTS.cover?(@bot_count)

      engine = BeanBazaar::Game.start(names: [ "You", *BOT_NAMES.first(@bot_count) ], random: @random)
      BeanBazaar::BotRunner.new(engine, human_index: HUMAN_INDEX).run
      Game.create!(state: engine.to_h, human_index: HUMAN_INDEX)
    end
  end
end
