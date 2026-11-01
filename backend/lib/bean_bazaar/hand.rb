module BeanBazaar
  # An ordered row of cards. A player's hand can never be reordered: new cards
  # join the back and planting takes from the front. The face-up cards in the
  # trading phase use the same row.
  class Hand
    attr_reader :cards

    def self.from_h(cards)
      new(cards.map(&:to_sym))
    end

    def initialize(cards = [])
      @cards = cards
    end

    def to_h
      cards
    end

    def add(new_cards)
      cards.concat(new_cards)
    end

    def front
      cards.first
    end

    def take_front
      cards.shift
    end

    def take_all
      cards.slice!(0..)
    end

    # Raises unless every index points at a different card in the row.
    def check!(indexes)
      raise IllegalMove, 'Pick each card only once' if indexes.uniq.size != indexes.size

      missing = indexes.find { |index| !index.between?(0, cards.size - 1) }
      raise IllegalMove, "There is no card at position #{missing}" if missing
    end

    # Positions of the asked-for beans, each card used once; nil if one is missing.
    # Lets a player ask for bean types without seeing another player's hand.
    def indexes_of(beans)
      beans.each_with_object([]) do |bean, indexes|
        index = cards.each_index.find { |candidate| cards[candidate] == bean.to_sym && !indexes.include?(candidate) }
        return nil if index.nil?

        indexes << index
      end
    end

    # Removes the cards at `indexes` and returns them in row order.
    def take_at(indexes)
      check!(indexes)
      indexes.sort.reverse.map { |index| cards.delete_at(index) }.reverse
    end

    def size
      cards.size
    end

    def empty?
      cards.empty?
    end
  end
end
