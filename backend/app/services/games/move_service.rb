module Games
  # Applies one move from the human, lets the bots respond, and saves the
  # result. Raises BeanBazaar::IllegalMove when the rules say no.
  class MoveService
    ACTIVE_PLAYER_MOVES = %w[plant_from_hand flip_cards trade end_trading].freeze

    def initialize(game:, move:)
      @game = game
      @move = move
    end

    def call
      # The row lock stops a double-clicked move from being applied twice.
      @game.with_lock do
        engine = @game.engine
        apply(engine)
        BeanBazaar::BotRunner.new(engine, human_index: human_index).run
        @game.store(engine)
      end
      @game
    end

    private

    def human_index
      @game.human_index
    end

    def apply(engine)
      type = @move[:type].to_s
      raise BeanBazaar::IllegalMove, "Wait for your turn" if ACTIVE_PLAYER_MOVES.include?(type) && engine.active_index != human_index

      case type
      when "plant_from_hand" then engine.plant_from_hand(number(:field_index))
      when "flip_cards" then engine.flip_cards
      when "trade" then trade(engine)
      when "end_trading" then engine.end_trading
      when "plant_pending"
        engine.plant_pending(player_index: human_index, pending_index: number(:pending_index), field_index: number(:field_index))
      when "harvest" then engine.harvest(player_index: human_index, field_index: number(:field_index))
      when "buy_third_field" then engine.buy_third_field(player_index: human_index)
      else raise BeanBazaar::IllegalMove, "Unknown move: #{type}"
      end
    end

    # Bots decide straight away, so a trade either happens or is turned down.
    def trade(engine)
      partner_index = number(:partner_index)
      raise BeanBazaar::IllegalMove, "You can't trade with yourself" if partner_index == human_index

      partner = engine.players.fetch(partner_index) { raise BeanBazaar::IllegalMove, "There is no player #{partner_index}" }
      offered = picked(engine.face_up, :face_up_indexes) + picked(engine.active_player.hand, :hand_indexes)
      partner_hand_indexes = indexes_for_beans(partner)
      requested = partner_hand_indexes.map { |index| partner.hand.cards[index] }
      bot = BeanBazaar::BotRunner.new(engine, human_index: human_index).bot(partner_index)
      raise BeanBazaar::IllegalMove, "#{partner.name} turned down your offer" if !bot.accepts?(offered: offered, requested: requested)

      engine.trade(
        partner_index: partner_index,
        face_up_indexes: numbers(:face_up_indexes),
        hand_indexes: numbers(:hand_indexes),
        partner_hand_indexes: partner_hand_indexes
      )
    end

    def picked(row, key)
      indexes = numbers(key)
      row.check!(indexes)
      indexes.map { |index| row.cards[index] }
    end

    # The human can't see a bot's hand, so they ask for bean types, as at a real table.
    def indexes_for_beans(partner)
      Array(@move[:partner_beans]).each_with_object([]) do |bean, indexes|
        index = partner.hand.cards.each_index.find { |candidate| partner.hand.cards[candidate].to_s == bean.to_s && !indexes.include?(candidate) }
        raise BeanBazaar::IllegalMove, "#{partner.name} has no #{bean} bean to give" if index.nil?

        indexes << index
      end
    end

    def number(key)
      Integer(@move[key])
    rescue ArgumentError, TypeError
      raise BeanBazaar::IllegalMove, "#{key} must be a number"
    end

    def numbers(key)
      Array(@move[key]).map { |value| Integer(value) }
    rescue ArgumentError, TypeError
      raise BeanBazaar::IllegalMove, "#{key} must be a list of numbers"
    end
  end
end
