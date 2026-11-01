class Games::MakeMove < ApplicationService
  # @param game [Game] the game to play the move in
  # @param move_params [ActionController::Parameters / Hash] the human's move: type plus its fields
  def initialize(game, move_params)
    super()

    @game = game
    @move_params = move_params

    # helper
    @engine = nil
    @state_before = nil
  end

  def call
    safe_transaction do
      load_game
      apply_move
      play_bot_turns
      remember_undo
      save_game

      @success = true
    end

    return_result(@success, root_name, @game, extra_params: extra_params)
  end

  private

  # the row lock stops a double-clicked move from being applied twice
  def load_game
    @game.lock!
    @engine = @game.engine
    @state_before = @engine.to_h.deep_stringify_keys
  end

  def apply_move
    check_turn
    check_offer

    case move_type
    when 'undo' then undo
    when 'plant_from_hand' then @engine.plant_from_hand(number(:field_index))
    when 'flip_cards' then @engine.flip_cards
    when 'trade' then trade
    when 'end_trading' then @engine.end_trading
    when 'plant_pending' then plant_pending
    when 'harvest' then @engine.harvest(player_index: human_index, field_index: number(:field_index))
    when 'buy_third_field' then @engine.buy_third_field(player_index: human_index)
    when 'accept_offer' then @engine.accept_offer
    when 'decline_offer' then @engine.decline_offer
    else illegal!('unknown_move', type: move_type)
    end
  end

  def play_bot_turns
    @game.bot_runner(@engine).run
  end

  # Puts the table back as it was before the human's last undoable move.
  def undo
    state = @game.undo_states.pop || illegal!('nothing_to_undo')
    @engine = BeanBazaar::Game.from_h(state)
  end

  # Keeps the state from before an undoable move, as long as the move revealed
  # nothing and no bot acted; anything else wipes the history.
  def remember_undo
    return if move_type == 'undo'

    @game.undo_states = undoable? ? (@game.undo_states + [@state_before]).last(Games::MAX_UNDOS) : []
  end

  # Saved log entries have string keys and fresh ones symbol keys, so compare them as strings.
  def undoable?
    return false if !Games::UNDOABLE_MOVES.include?(move_type)

    seen = @state_before['event_seq']
    @engine.log.map(&:stringify_keys).all? { |event| event['seq'] <= seen || Games::UNDOABLE_EVENTS.include?(event['type'].to_s) }
  end

  def save_game
    @game.store(@engine)
  end

  def check_turn
    return if !Games::ACTIVE_PLAYER_MOVES.include?(move_type)
    return if @engine.active_index == human_index

    illegal!('wait_for_turn')
  end

  # only the human can answer an offer, and only one made to them
  def check_offer
    return if !Games::OFFER_ANSWERS.include?(move_type)
    return if @engine.offer&.fetch('partner_index') == human_index

    illegal!('no_offer')
  end

  def plant_pending
    @engine.plant_pending(
      player_index: human_index,
      pending_index: number(:pending_index),
      field_index: number(:field_index),
    )
  end

  # bots decide straight away, so a trade either happens or is turned down
  def trade
    partner = trade_partner
    partner_hand_indexes = partner_hand_indexes_for(partner)
    check_bot_accepts(partner, partner_hand_indexes)

    @engine.trade(
      partner_index: number(:partner_index),
      face_up_indexes: numbers(:face_up_indexes),
      hand_indexes: numbers(:hand_indexes),
      partner_hand_indexes: partner_hand_indexes,
    )
  end

  def trade_partner
    partner_index = number(:partner_index)
    illegal!('trade_with_yourself') if partner_index == human_index

    @engine.players.fetch(partner_index) { illegal!('no_player', index: partner_index) }
  end

  def check_bot_accepts(partner, partner_hand_indexes)
    offered = picked_cards(@engine.face_up, :face_up_indexes) + picked_cards(@engine.active_player.hand, :hand_indexes)
    requested = partner_hand_indexes.map { |index| partner.hand.cards[index] }
    bot = @game.bot_runner(@engine).bot(@engine.players.index(partner))
    return if bot.accepts?(offered: offered, requested: requested)

    illegal!('turned_down', name: partner.name)
  end

  # @param row [BeanBazaar::Hand] face-up cards or a hand
  # @param key [Symbol] the move field holding the picked indexes
  # @return [Array<Symbol>] the picked cards
  def picked_cards(row, key)
    indexes = numbers(key)
    row.check!(indexes)
    indexes.map { |index| row.cards[index] }
  end

  # The human can't see a bot's hand, so they ask for bean types, as at a real table.
  # @return [Array<Integer>] hand positions of the asked-for beans
  def partner_hand_indexes_for(partner)
    beans = Array(@move_params[:partner_beans])
    partner.hand.indexes_of(beans) || illegal!('no_bean_to_give', name: partner.name)
  end

  def move_type
    @move_params[:type].to_s
  end

  def human_index
    @game.human_index
  end

  def number(key)
    Integer(@move_params[key])
  rescue ArgumentError, TypeError
    illegal!('not_a_number', key: key)
  end

  def numbers(key)
    Array(@move_params[key]).map { |value| Integer(value) }
  rescue ArgumentError, TypeError
    illegal!('not_a_list', key: key)
  end

  # @param message_key [String] key under game.service_messages.make_move
  # @raise [BeanBazaar::IllegalMove] rolled back by safe_transaction and shown as the alert
  def illegal!(message_key, **options)
    raise BeanBazaar::IllegalMove, I18n.t("game.service_messages.make_move.#{message_key}", **options)
  end

  # rule breaks explain themselves; anything else gets the general message
  def error_message
    return @exception.message if @exception.is_a?(BeanBazaar::IllegalMove)

    I18n.t('game.service_messages.make_move.error_default')
  end

  def root_name
    :game
  end

  def extra_params
    { alert: error_message }
  end
end
