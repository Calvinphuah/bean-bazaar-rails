module BeanBazaar
  # Lets the bots play until the human has something to do or the game ends.
  # With no human (human_index: nil) it plays a whole bots-only game.
  class BotRunner
    MAX_STEPS = 10_000

    def initialize(game, human_index:, bot_class: Bots::SimpleBot)
      @game = game
      @human_index = human_index
      @bot_class = bot_class
    end

    def run
      MAX_STEPS.times do
        bots_plant_pending if @game.phase == :plant_pending
        return if @game.over? || waiting_for_human?

        play_active_bot
      end
      raise "Bots made no progress after #{MAX_STEPS} steps"
    end

    def bot(player_index)
      @bot_class.new(@game, player_index)
    end

    private

    def bot_indexes
      @game.players.each_index.reject { |index| index == @human_index }
    end

    def waiting_for_human?
      return false if @human_index.nil?
      return @game.players[@human_index].pending.any? if @game.phase == :plant_pending

      @game.active_index == @human_index
    end

    def bots_plant_pending
      bot_indexes.each { |index| bot(index).plant_pending }
    end

    # Only :plant and :trade reach here; :plant_pending is handled for every bot above.
    def play_active_bot
      active_bot = bot(@game.active_index)
      return active_bot.play_plant_phase if @game.phase == :plant

      active_bot.play_trade_phase(partner_indexes: bot_indexes - [ @game.active_index ])
    end
  end
end
