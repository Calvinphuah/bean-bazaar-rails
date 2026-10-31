module BeanBazaar
  # Runs a whole game. Each turn has four phases:
  #   :plant          plant the front hand card, optionally the next one
  #   :trade          flip 2 cards, then trade or gift them and hand cards
  #   :plant_pending  every player plants the cards they traded for or kept
  #   (draw)          the active player draws 3 to the back of their hand
  # Players may harvest or buy a third field at any time before the end.
  class Game
    PLAYER_COUNTS = 3..5
    HAND_SIZE = 5
    MAX_HAND_PLANTS = 2
    FLIP_COUNT = 2
    DRAW_COUNT = 3
    LOG_SIZE = 40

    attr_reader :players, :deck, :phase, :active_index, :face_up, :hand_plants, :log

    def self.start(names:, random: Random.new)
      raise ArgumentError, "Bean Bazaar needs #{PLAYER_COUNTS} players" if !PLAYER_COUNTS.cover?(names.size)

      deck = Deck.shuffled(random: random)
      players = names.map { |name| Player.new(name: name, hand: Hand.new(deck.draw(HAND_SIZE))) }
      new(players: players, deck: deck)
    end

    # Rebuilds a game from #to_h after a JSON round trip (string keys and values).
    def self.from_h(hash)
      new(
        players: hash["players"].map { |player| Player.from_h(player) },
        deck: Deck.from_h(hash["deck"]),
        phase: hash["phase"].to_sym,
        active_index: hash["active_index"],
        face_up: Hand.from_h(hash["face_up"]),
        hand_plants: hash["hand_plants"],
        log: hash.fetch("log", [])
      )
    end

    def initialize(players:, deck:, phase: :plant, active_index: 0, face_up: Hand.new, hand_plants: 0, log: [])
      @players = players
      @deck = deck
      @phase = phase
      @active_index = active_index
      @face_up = face_up
      @hand_plants = hand_plants
      @log = log
    end

    def to_h
      {
        players: players.map(&:to_h),
        deck: deck.to_h,
        phase: phase,
        active_index: active_index,
        face_up: face_up.to_h,
        hand_plants: hand_plants,
        log: log
      }
    end

    def active_player
      players[active_index]
    end

    def over?
      phase == :over
    end

    def winners
      raise IllegalMove, "The game isn't over yet" if !over?

      top = players.map(&:coins).max
      players.select { |player| player.coins == top }
    end

    def plant_from_hand(field_index)
      require_phase(:plant)
      raise IllegalMove, "You can plant at most #{MAX_HAND_PLANTS} cards from your hand" if hand_plants >= MAX_HAND_PLANTS
      raise IllegalMove, "Your hand is empty" if active_player.hand.empty?

      card = active_player.hand.front
      active_player.plant(card, field_index)
      active_player.hand.take_front
      @hand_plants += 1
      note("#{active_player.name} planted #{bean_names([ card ])}")
    end

    def flip_cards
      require_phase(:plant)
      raise IllegalMove, "Plant the front card of your hand first" if hand_plants.zero? && !active_player.hand.empty?

      @face_up = Hand.new(deck.draw(FLIP_COUNT))
      @phase = :trade
      note("#{active_player.name} flipped #{bean_names(face_up.cards)}") if !face_up.empty?
      finish if deck.exhausted?
    end

    def trade(partner_index:, face_up_indexes: [], hand_indexes: [], partner_hand_indexes: [])
      require_phase(:trade)

      partner = player_at(partner_index)
      offered, requested = Trade.new(
        active: active_player,
        partner: partner,
        face_up: face_up,
        face_up_indexes: face_up_indexes,
        hand_indexes: hand_indexes,
        partner_hand_indexes: partner_hand_indexes
      ).execute
      note(trade_message(partner, offered, requested))
    end

    # Face-up cards nobody traded for stay with the active player.
    def end_trading
      require_phase(:trade)

      kept = face_up.take_all
      active_player.receive(kept)
      note("#{active_player.name} kept #{bean_names(kept)}") if kept.any?
      @phase = :plant_pending
      finish_turn if nothing_pending?
    end

    def plant_pending(player_index:, pending_index:, field_index:)
      require_phase(:plant_pending)

      player_at(player_index).plant_pending(pending_index, field_index)
      finish_turn if nothing_pending?
    end

    def harvest(player_index:, field_index:)
      raise IllegalMove, "The game is over" if over?

      player = player_at(player_index)
      coins_before = player.coins
      field = player.fields[field_index]
      bean = field&.bean
      count = field&.count
      deck.discard(player.harvest(field_index))
      earned = player.coins - coins_before
      note("#{player.name} harvested #{count} #{BeanType.find(bean).name} for #{earned} #{earned == 1 ? 'coin' : 'coins'}")
    end

    def buy_third_field(player_index:)
      raise IllegalMove, "The game is over" if over?

      player = player_at(player_index)
      deck.discard(player.buy_third_field)
      note("#{player.name} bought a third field")
    end

    private

    def require_phase(expected)
      raise IllegalMove, "You can't do that during the #{phase} phase" if phase != expected
    end

    def player_at(index)
      players.fetch(index) { raise IllegalMove, "There is no player #{index}" }
    end

    def nothing_pending?
      players.all? { |player| player.pending.empty? }
    end

    def finish_turn
      active_player.hand.add(deck.draw(DRAW_COUNT))
      return finish if deck.exhausted?

      @active_index = (active_index + 1) % players.size
      @hand_plants = 0
      @phase = :plant
      note("#{active_player.name}'s turn")
    end

    # The deck ran out for the last time: clear the table and harvest everything.
    def finish
      deck.discard(face_up.take_all)
      players.each do |player|
        deck.discard(player.pending.slice!(0..))
        deck.discard(player.harvest_all)
      end
      @phase = :over
      note("The deck ran out for the third time. Game over!")
    end

    def note(message)
      @log = (log + [ message ]).last(LOG_SIZE)
    end

    def bean_names(cards)
      cards.map { |card| BeanType.find(card).name }.join(" and ")
    end

    def trade_message(partner, offered, requested)
      return "#{partner.name} gave #{bean_names(requested)} to #{active_player.name}" if offered.empty?
      return "#{active_player.name} gave #{bean_names(offered)} to #{partner.name}" if requested.empty?

      "#{active_player.name} traded #{bean_names(offered)} to #{partner.name} for #{bean_names(requested)}"
    end
  end
end
