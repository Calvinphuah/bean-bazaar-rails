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

    attr_reader :players, :deck, :phase, :active_index, :face_up, :hand_plants

    def self.start(names:, random: Random.new)
      raise ArgumentError, "Bean Bazaar needs #{PLAYER_COUNTS} players" if !PLAYER_COUNTS.cover?(names.size)

      deck = Deck.shuffled(random: random)
      players = names.map { |name| Player.new(name: name, hand: Hand.new(deck.draw(HAND_SIZE))) }
      new(players: players, deck: deck)
    end

    def initialize(players:, deck:, phase: :plant, active_index: 0, face_up: Hand.new, hand_plants: 0)
      @players = players
      @deck = deck
      @phase = phase
      @active_index = active_index
      @face_up = face_up
      @hand_plants = hand_plants
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

      active_player.plant(active_player.hand.front, field_index)
      active_player.hand.take_front
      @hand_plants += 1
    end

    def flip_cards
      require_phase(:plant)
      raise IllegalMove, "Plant the front card of your hand first" if hand_plants.zero? && !active_player.hand.empty?

      @face_up = Hand.new(deck.draw(FLIP_COUNT))
      @phase = :trade
      finish if deck.exhausted?
    end

    def trade(partner_index:, face_up_indexes: [], hand_indexes: [], partner_hand_indexes: [])
      require_phase(:trade)

      Trade.new(
        active: active_player,
        partner: player_at(partner_index),
        face_up: face_up,
        face_up_indexes: face_up_indexes,
        hand_indexes: hand_indexes,
        partner_hand_indexes: partner_hand_indexes
      ).execute
    end

    # Face-up cards nobody traded for stay with the active player.
    def end_trading
      require_phase(:trade)

      active_player.receive(face_up.take_all)
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

      deck.discard(player_at(player_index).harvest(field_index))
    end

    def buy_third_field(player_index:)
      raise IllegalMove, "The game is over" if over?

      deck.discard(player_at(player_index).buy_third_field)
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
    end

    # The deck ran out for the last time: clear the table and harvest everything.
    def finish
      deck.discard(face_up.take_all)
      players.each do |player|
        deck.discard(player.pending.slice!(0..))
        deck.discard(player.harvest_all)
      end
      @phase = :over
    end
  end
end
