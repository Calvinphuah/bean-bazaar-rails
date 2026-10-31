module BeanBazaar
  # One seat at the table: a hand, two or three fields, earned coins, and the
  # traded or face-up cards waiting to be planted this turn.
  class Player
    STARTING_FIELDS = 2
    MAX_FIELDS = 3
    THIRD_FIELD_PRICE = 3

    attr_reader :name, :hand, :fields, :coin_cards, :pending

    def self.from_h(hash)
      new(
        name: hash["name"],
        hand: Hand.from_h(hash["hand"]),
        fields: hash["fields"].map { |field| Field.from_h(field) },
        coin_cards: hash["coin_cards"].map(&:to_sym),
        pending: hash["pending"].map(&:to_sym)
      )
    end

    def initialize(name:, hand: Hand.new, fields: Array.new(STARTING_FIELDS) { Field.new }, coin_cards: [], pending: [])
      @name = name
      @hand = hand
      @fields = fields
      @coin_cards = coin_cards
      @pending = pending
    end

    def to_h
      { name: name, hand: hand.to_h, fields: fields.map(&:to_h), coin_cards: coin_cards, pending: pending }
    end

    # Harvested cards flip to their coin side, so coins are cards too.
    def coins
      coin_cards.size
    end

    def plant(card, field_index)
      field(field_index).plant(card)
    end

    def receive(cards)
      pending.concat(cards)
    end

    def plant_pending(pending_index, field_index)
      card = pending.fetch(pending_index) { raise IllegalMove, "There is no card at position #{pending_index}" }
      plant(card, field_index)
      pending.delete_at(pending_index)
    end

    # Returns the cards that go to the discard pile.
    def harvest(field_index)
      target = field(field_index)
      raise IllegalMove, "That field is empty" if target.empty?
      raise IllegalMove, "Harvest a field with more beans first" if protected?(target)

      collect(target)
    end

    # End of game: every field is harvested, so the 1-bean rule doesn't apply.
    def harvest_all
      fields.reject(&:empty?).flat_map { |target| collect(target) }
    end

    # Returns the coin cards spent, which go to the discard pile.
    def buy_third_field
      raise IllegalMove, "You already have #{MAX_FIELDS} fields" if fields.size >= MAX_FIELDS
      raise IllegalMove, "A third field costs #{THIRD_FIELD_PRICE} coins" if coins < THIRD_FIELD_PRICE

      fields << Field.new
      coin_cards.pop(THIRD_FIELD_PRICE)
    end

    private

    def field(index)
      fields.fetch(index) { raise IllegalMove, "There is no field #{index}" }
    end

    # A lone bean can't be harvested while another field has more than one.
    def protected?(target)
      target.count == 1 && fields.any? { |other| other.count > 1 }
    end

    def collect(target)
      coins = target.coins
      cards = target.harvest
      coin_cards.concat(cards.first(coins))
      cards.drop(coins)
    end
  end
end
