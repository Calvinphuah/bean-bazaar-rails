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
    LOG_SIZE = 60

    attr_reader :players, :deck, :phase, :active_index, :face_up, :hand_plants, :log, :offer, :offers_this_turn, :lacking

    def self.start(names:, random: Random.new)
      raise ArgumentError, "Bean Bazaar needs #{PLAYER_COUNTS} players" if !PLAYER_COUNTS.cover?(names.size)

      deck = Deck.shuffled(random: random)
      players = names.map { |name| Player.new(name: name, hand: Hand.new(deck.draw(HAND_SIZE))) }
      new(players: players, deck: deck)
    end

    # Rebuilds a game from #to_h after a JSON round trip (string keys and values).
    def self.from_h(hash)
      new(
        players: hash['players'].map { |player| Player.from_h(player) },
        deck: Deck.from_h(hash['deck']),
        phase: hash['phase'].to_sym,
        active_index: hash['active_index'],
        face_up: Hand.from_h(hash['face_up']),
        hand_plants: hash['hand_plants'],
        log: hash.fetch('log', []),
        event_seq: hash.fetch('event_seq', 0),
        offer: hash['offer'],
        offers_this_turn: hash.fetch('offers_this_turn', 0),
        lacking: hash.fetch('lacking', []).map { |beans| beans.map(&:to_sym) },
      )
    end

    def initialize(
      players:, deck:, phase: :plant, active_index: 0, face_up: Hand.new, hand_plants: 0,
      log: [], event_seq: 0, offer: nil, offers_this_turn: 0, lacking: []
    )
      @players = players
      @deck = deck
      @phase = phase
      @active_index = active_index
      @face_up = face_up
      @hand_plants = hand_plants
      @log = log
      @event_seq = event_seq
      @offer = offer
      @offers_this_turn = offers_this_turn
      # Beans each player has said they hold none of, by turning down an offer
      # they couldn't meet. Forgotten once that player draws new cards.
      @lacking = players.each_index.map { |index| lacking.fetch(index, []) }
    end

    def to_h
      {
        players: players.map(&:to_h),
        deck: deck.to_h,
        phase: phase,
        active_index: active_index,
        face_up: face_up.to_h,
        hand_plants: hand_plants,
        log: log,
        event_seq: @event_seq,
        offer: offer,
        offers_this_turn: offers_this_turn,
        lacking: lacking,
      }
    end

    # What everyone at the table can see; hands are counts only. Each log entry keeps
    # one, so a client can replay the bots' moves step by step.
    def public_table
      {
        phase: phase,
        active_index: active_index,
        deck: deck.summary,
        face_up: face_up.cards.dup,
        players: players.map do |player|
          { hand_size: player.hand.size, coins: player.coins, fields: player.fields.map(&:to_h), pending: player.pending.dup }
        end,
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
      raise IllegalMove, "You can plant at most #{MAX_HAND_PLANTS} cards from your hand" if hand_plants >= MAX_HAND_PLANTS

      require_phase(:plant)
      raise IllegalMove, 'Your hand is empty' if active_player.hand.empty?

      card = active_player.hand.front
      active_player.plant(card, field_index)
      active_player.hand.take_front
      @hand_plants += 1
      note(:plant, active_index, "#{active_player.name} planted #{bean_names([card])}")
      flip_cards if !can_plant_from_hand?
    end

    def flip_cards
      require_phase(:plant)
      raise IllegalMove, 'Plant the front card of your hand first' if hand_plants.zero? && !active_player.hand.empty?

      @face_up = Hand.new(deck.draw(FLIP_COUNT))
      @phase = :trade
      note(:flip, active_index, "#{active_player.name} flipped #{bean_names(face_up.cards)}") if !face_up.empty?
      finish if deck.exhausted?
    end

    def trade(partner_index:, face_up_indexes: [], hand_indexes: [], partner_hand_indexes: [])
      require_phase(:trade)
      require_no_offer

      execute_trade(player_at(partner_index), face_up_indexes, hand_indexes, partner_hand_indexes)
    end

    # The active player asks another player for bean types, since hands are hidden.
    # The offer waits until that player accepts or declines it.
    def propose(partner_index:, face_up_indexes: [], hand_indexes: [], partner_beans: [])
      require_phase(:trade)
      require_no_offer
      partner = player_at(partner_index)
      raise IllegalMove, "You can't trade with yourself" if partner.equal?(active_player)
      raise IllegalMove, 'An offer needs at least one card' if [face_up_indexes, hand_indexes, partner_beans].all?(&:empty?)

      face_up.check!(face_up_indexes)
      active_player.hand.check!(hand_indexes)
      @offer = {
        'partner_index' => partner_index,
        'face_up_indexes' => face_up_indexes,
        'hand_indexes' => hand_indexes,
        'partner_beans' => partner_beans.map(&:to_s),
      }
      @offers_this_turn += 1
      note(:offer, active_index, offer_message(partner))
    end

    def accept_offer
      waiting = require_offer
      partner = player_at(waiting['partner_index'])
      partner_hand_indexes = partner.hand.indexes_of(waiting['partner_beans'])
      # Only the player answering sees this, so it speaks to them.
      raise IllegalMove, "You have no #{bean_names(waiting['partner_beans'])} to give" if partner_hand_indexes.nil?

      @offer = nil
      execute_trade(partner, waiting['face_up_indexes'], waiting['hand_indexes'], partner_hand_indexes)
    end

    def decline_offer
      waiting = require_offer
      partner = player_at(waiting['partner_index'])
      @offer = nil
      remember_lacking(waiting['partner_index'], waiting['partner_beans'].map(&:to_sym))
      note(:decline, waiting['partner_index'], "#{partner.name} turned down #{active_player.name}'s offer")
    end

    # Face-up cards nobody traded for stay with the active player.
    def end_trading
      require_phase(:trade)
      require_no_offer

      kept = face_up.take_all
      active_player.receive(kept)
      note(:keep, active_index, "#{active_player.name} kept #{bean_names(kept)}") if kept.any?
      @phase = :plant_pending
      finish_turn if nothing_pending?
    end

    def plant_pending(player_index:, pending_index:, field_index:)
      require_phase(:plant_pending)

      player = player_at(player_index)
      card = player.pending[pending_index]
      player.plant_pending(pending_index, field_index)
      note(:plant, player_index, "#{player.name} planted #{bean_names([card])}")
      finish_turn if nothing_pending?
    end

    def harvest(player_index:, field_index:)
      raise IllegalMove, 'The game is over' if over?

      player = player_at(player_index)
      coins_before = player.coins
      field = player.fields[field_index]
      bean = field&.bean
      count = field&.count
      deck.discard(player.harvest(field_index))
      earned = player.coins - coins_before
      note(:harvest, player_index, "#{player.name} harvested #{count} #{BeanType.find(bean).name} for #{coin_text(earned)}")
    end

    def buy_third_field(player_index:)
      raise IllegalMove, 'The game is over' if over?

      player = player_at(player_index)
      deck.discard(player.buy_third_field)
      note(:buy_field, player_index, "#{player.name} bought a third field")
    end

    private

    # Once a second card is planted, or the hand runs out, the only move left is the flip.
    def can_plant_from_hand?
      hand_plants < MAX_HAND_PLANTS && !active_player.hand.empty?
    end

    def require_phase(expected)
      raise IllegalMove, "You can't do that during the #{phase} phase" if phase != expected
    end

    def require_no_offer
      raise IllegalMove, 'Answer the waiting offer first' if offer
    end

    def require_offer
      offer || raise(IllegalMove, 'There is no offer to answer')
    end

    def player_at(index)
      players.fetch(index) { raise IllegalMove, "There is no player #{index}" }
    end

    def nothing_pending?
      players.all? { |player| player.pending.empty? }
    end

    def execute_trade(partner, face_up_indexes, hand_indexes, partner_hand_indexes)
      offered, requested = Trade.new(
        active: active_player,
        partner: partner,
        face_up: face_up,
        face_up_indexes: face_up_indexes,
        hand_indexes: hand_indexes,
        partner_hand_indexes: partner_hand_indexes,
      ).execute
      note(:trade, active_index, trade_message(partner, offered, requested))
    end

    # The partner couldn't have met this ask, so others stop asking for those beans.
    def remember_lacking(player_index, asked)
      held = players[player_index].hand.cards.tally
      missing = asked.tally.filter_map { |bean, count| bean if held.fetch(bean, 0) < count }
      @lacking[player_index] = (lacking[player_index] + missing).uniq
    end

    def finish_turn
      active_player.hand.add(deck.draw(DRAW_COUNT))
      @lacking[active_index] = []
      return finish if deck.exhausted?

      @active_index = (active_index + 1) % players.size
      @hand_plants = 0
      @offers_this_turn = 0
      @phase = :plant
      note(:turn, active_index, "#{active_player.name}'s turn")
    end

    # The deck ran out for the last time: clear the table and harvest everything.
    def finish
      @offer = nil
      deck.discard(face_up.take_all)
      players.each do |player|
        deck.discard(player.pending.slice!(0..))
        deck.discard(player.harvest_all)
      end
      @phase = :over
      note(:game_over, nil, 'The deck ran out for the third time. Game over!')
    end

    # @param type [Symbol] what happened: plant, flip, trade, offer, harvest, turn...
    # @param player_index [Integer, nil] who did it
    def note(type, player_index, text)
      @event_seq += 1
      entry = { seq: @event_seq, type: type, player: player_index, text: text, table: public_table }
      @log = (log + [entry]).last(LOG_SIZE)
    end

    def bean_names(cards)
      cards.map { |card| BeanType.find(card.to_sym).name }.join(' and ')
    end

    def coin_text(coins)
      "#{coins} #{coins == 1 ? 'coin' : 'coins'}"
    end

    def trade_message(partner, offered, requested)
      return "#{partner.name} gave #{bean_names(requested)} to #{active_player.name}" if offered.empty?
      return "#{active_player.name} gave #{bean_names(offered)} to #{partner.name}" if requested.empty?

      "#{active_player.name} traded #{bean_names(offered)} to #{partner.name} for #{bean_names(requested)}"
    end

    def offer_message(partner)
      gives = offer['face_up_indexes'].map { |index| face_up.cards[index] } +
              offer['hand_indexes'].map { |index| active_player.hand.cards[index] }
      asks = offer['partner_beans']
      return "#{active_player.name} asks #{partner.name} for #{bean_names(asks)}" if gives.empty?
      return "#{active_player.name} offers #{partner.name} #{bean_names(gives)} as a gift" if asks.empty?

      "#{active_player.name} offers #{partner.name} #{bean_names(gives)} for #{bean_names(asks)}"
    end
  end
end
