module BeanBazaar
  # Draw pile plus discard pile. When the draw pile runs dry the discards are
  # shuffled back in; the third time it runs dry the game is over.
  class Deck
    MAX_RUN_OUTS = 3

    attr_reader :draw_pile, :discard_pile, :run_outs

    def self.shuffled(random: Random.new)
      new(draw_pile: BeanType.full_deck.shuffle(random: random), random: random)
    end

    def initialize(draw_pile:, discard_pile: [], run_outs: 0, random: Random.new)
      @draw_pile = draw_pile
      @discard_pile = discard_pile
      @run_outs = run_outs
      @random = random
    end

    # Returns up to `count` cards; fewer once the deck is exhausted.
    def draw(count)
      Array.new(count) { draw_one }.compact
    end

    def discard(cards)
      discard_pile.concat(cards)
    end

    def exhausted?
      run_outs >= MAX_RUN_OUTS
    end

    private

    def draw_one
      return nil if exhausted?

      refill if draw_pile.empty?
      draw_pile.shift
    end

    def refill
      @run_outs += 1
      return if exhausted?

      @draw_pile = discard_pile.shuffle(random: @random)
      @discard_pile = []
    end
  end
end
