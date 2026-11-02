class Games::Create < ApplicationService
  # @param bot_count [Integer / String] how many bots the human plays against
  # @param bot_level [String] "easy", "normal" or "smart", see Games::BOT_LEVELS
  # @param random [Random] shuffles the deck; seeded in specs
  def initialize(bot_count, bot_level = Games::DEFAULT_BOT_LEVEL, random: Random.new)
    super()

    @bot_count = Integer(bot_count, exception: false)
    @bot_level = bot_level.to_s
    @random = random

    # helper
    @engine = nil
    @game = nil
  end

  def call
    # check the bot count and level are supported
    return return_result(false, root_name, nil, extra_params: extra_params) if !valid_options?

    safe_transaction do
      build_game
      deal_cards
      play_bot_turns
      save_game

      @success = true
    end

    return_result(@success, root_name, @game, extra_params: extra_params)
  end

  private

  def valid_options?
    valid_bot_count? && valid_bot_level?
  end

  def valid_bot_count?
    Games::BOT_COUNTS.cover?(@bot_count)
  end

  def valid_bot_level?
    Games::BOT_LEVELS.key?(@bot_level)
  end

  def build_game
    @game = Game.new(human_index: Games::HUMAN_INDEX, bot_level: @bot_level)
  end

  # the human always sits in seat 0, followed by the bots
  def deal_cards
    @engine = BeanBazaar::Game.start(names: ['You', *Games::BOT_NAMES.first(@bot_count)], random: @random)
  end

  # bots play until it is the human's move
  def play_bot_turns
    @game.bot_runner(@engine).run
  end

  def save_game
    @game.state = @engine.to_h
    @game.save!
  end

  def success_message
    I18n.t('game.service_messages.create.success_default')
  end

  def error_message
    if !valid_bot_count?
      return I18n.t('game.service_messages.create.invalid_bot_count', min: Games::BOT_COUNTS.min, max: Games::BOT_COUNTS.max)
    end
    return I18n.t('game.service_messages.create.invalid_bot_level') if !valid_bot_level?

    I18n.t('game.service_messages.create.error_default')
  end

  def root_name
    :game
  end

  def extra_params
    { success_message: success_message, alert: error_message }
  end
end
