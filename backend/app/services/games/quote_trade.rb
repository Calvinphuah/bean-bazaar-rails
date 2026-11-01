class Games::QuoteTrade < ApplicationService
  # @param game [Game] the game the human is trading in
  # @param quote_params [ActionController::Parameters / Hash] face_up_indexes, hand_indexes, partner_beans
  def initialize(game, quote_params)
    super()

    @game = game
    @quote_params = quote_params

    # helper
    @engine = nil
    @answers = nil
  end

  # Asks every bot what it would say to the offer, without trading anything.
  def call
    safe_transaction do
      load_game
      check_trade_phase
      collect_answers

      @success = true
    end

    return_result(@success, root_name, { answers: @answers }, extra_params: extra_params)
  end

  private

  def load_game
    @engine = @game.engine
  end

  def check_trade_phase
    illegal!('wait_for_turn') if @engine.active_index != human_index || @engine.phase != :trade
  end

  # @return [Array<Hash>] one { player:, answer: } per bot; answer is accept, decline or missing.
  #   A decline may carry counter: { give:, ask: }, a smaller deal that bot would take.
  def collect_answers
    offered = picked_cards(@engine.face_up, :face_up_indexes) + picked_cards(@engine.active_player.hand, :hand_indexes)
    runner = @game.bot_runner(@engine)

    @answers = bot_indexes.map do |index|
      { player: index }.merge(answer_for(runner.bot(index), @engine.players[index], offered))
    end
  end

  def answer_for(bot, partner, offered)
    hand_indexes = partner.hand.indexes_of(asked_beans)
    return { answer: 'missing' } if hand_indexes.nil?

    requested = hand_indexes.map { |index| partner.hand.cards[index] }
    return { answer: 'accept' } if bot.accepts?(offered: offered, requested: requested)

    counter = bot.counter_offer(offered: offered, requested: requested)
    return { answer: 'decline' } if counter.nil?

    { answer: 'decline', counter: { give: counter[:offered].map(&:to_s), ask: counter[:requested].map(&:to_s) } }
  end

  def bot_indexes
    @engine.players.each_index.reject { |index| index == human_index }
  end

  def asked_beans
    Array(@quote_params[:partner_beans])
  end

  # @param row [BeanBazaar::Hand] face-up cards or the human's hand
  # @param key [Symbol] the param holding the picked indexes
  # @return [Array<Symbol>] the picked cards
  def picked_cards(row, key)
    indexes = Array(@quote_params[key]).map { |value| Integer(value) }
    row.check!(indexes)
    indexes.map { |index| row.cards[index] }
  rescue ArgumentError, TypeError
    illegal!('not_a_list', key: key)
  end

  def human_index
    @game.human_index
  end

  # @raise [BeanBazaar::IllegalMove] rolled back by safe_transaction and shown as the alert
  def illegal!(message_key, **options)
    raise BeanBazaar::IllegalMove, I18n.t("game.service_messages.make_move.#{message_key}", **options)
  end

  def error_message
    return @exception.message if @exception.is_a?(BeanBazaar::IllegalMove)

    I18n.t('game.service_messages.make_move.error_default')
  end

  def root_name
    :quote
  end

  def extra_params
    { alert: error_message }
  end
end
