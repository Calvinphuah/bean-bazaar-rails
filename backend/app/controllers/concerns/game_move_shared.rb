# Reading the human's picked cards and raising rule breaks, for the services
# that check a move or a trade quote. Each service names its message group and
# the params holding the picks.
module GameMoveShared
  private

  # @param row [BeanBazaar::Hand] face-up cards or a hand
  # @param key [Symbol] the param holding the picked indexes
  # @return [Array<Symbol>] the picked cards
  def picked_cards(row, key)
    indexes = numbers(key)
    row.check!(indexes)
    indexes.map { |index| row.cards[index] }
  end

  # @return [Array<Symbol>] the face-up and hand cards the active human offers
  def offered_cards
    picked_cards(@engine.face_up, :face_up_indexes) + picked_cards(@engine.active_player.hand, :hand_indexes)
  end

  # While bidding: the human's hand cards for the active bot's face-up cards and asked-for beans.
  # @return [Array(Array<Symbol>, Array<Symbol>)] what the bot is offered and what it gives up
  def bid_cards
    offered = picked_cards(@engine.players[human_index].hand, :hand_indexes)
    requested = picked_cards(@engine.face_up, :face_up_indexes) + asked_beans.map(&:to_sym)
    [offered, requested]
  end

  def asked_beans
    Array(picks_params[:partner_beans])
  end

  def numbers(key)
    Array(picks_params[key]).map { |value| Integer(value) }
  rescue ArgumentError, TypeError
    illegal!('not_a_list', key: key)
  end

  def human_index
    @game.human_index
  end

  # @param message_key [String] key under game.service_messages.<message_group>
  # @raise [BeanBazaar::IllegalMove] rolled back by safe_transaction and shown as the alert
  def illegal!(message_key, **options)
    raise BeanBazaar::IllegalMove, I18n.t("game.service_messages.#{message_group}.#{message_key}", **options)
  end

  # rule breaks explain themselves; anything else gets the general message
  def error_message
    return @exception.message if @exception.is_a?(BeanBazaar::IllegalMove)

    I18n.t("game.service_messages.#{message_group}.error_default")
  end
end
