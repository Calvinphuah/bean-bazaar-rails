class Games::QuoteTrade < ApplicationService
  include GameMoveShared

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
    return if bidding?

    illegal!('wait_for_turn') if @engine.active_index != human_index || @engine.phase != :trade
  end

  def bidding?
    @engine.bidding == human_index
  end

  # @return [Array<Hash>] one { player:, answer: } per bot; answer is accept, decline or missing.
  #   A decline may carry counter: { give:, ask: }, a smaller deal that bot would take.
  def collect_answers
    return collect_bid_answer if bidding?

    runner = @game.bot_runner(@engine)

    @answers = runner.bot_indexes.map do |index|
      { player: index }.merge(answer_for(runner.bot(index), @engine.players[index], offered_cards))
    end
  end

  # While bidding only the active bot answers: your hand cards for its face-up
  # cards and the beans you ask it for.
  def collect_bid_answer
    @answers = [{ player: @engine.active_index, answer: bid_answer }]
  end

  def bid_answer
    return 'missing' if @engine.active_player.hand.indexes_of(asked_beans).nil?

    offered, requested = bid_cards
    @game.bot_runner(@engine).bot(@engine.active_index).accepts?(offered: offered, requested: requested) ? 'accept' : 'decline'
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

  def picks_params
    @quote_params
  end

  def message_group
    'quote_trade'
  end

  def root_name
    :quote
  end

  def extra_params
    { alert: error_message }
  end
end
