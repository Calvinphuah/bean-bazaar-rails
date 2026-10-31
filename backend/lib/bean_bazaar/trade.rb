module BeanBazaar
  # A deal between the active player and one other player. The active player
  # can offer face-up and hand cards; the partner offers hand cards only. One
  # side may be empty, which makes it a gift. Every traded card goes to the
  # receiver's pending cards, to be planted this turn.
  class Trade
    def initialize(active:, partner:, face_up:, face_up_indexes: [], hand_indexes: [], partner_hand_indexes: [])
      @active = active
      @partner = partner
      @face_up = face_up
      @face_up_indexes = face_up_indexes
      @hand_indexes = hand_indexes
      @partner_hand_indexes = partner_hand_indexes
    end

    def execute
      validate!

      offered = @face_up.take_at(@face_up_indexes) + @active.hand.take_at(@hand_indexes)
      requested = @partner.hand.take_at(@partner_hand_indexes)
      @partner.receive(offered)
      @active.receive(requested)
    end

    private

    # Checks every side before moving any card, so a bad trade changes nothing.
    def validate!
      raise IllegalMove, "You can't trade with yourself" if @active.equal?(@partner)
      raise IllegalMove, "A trade needs at least one card" if [ @face_up_indexes, @hand_indexes, @partner_hand_indexes ].all?(&:empty?)

      @face_up.check!(@face_up_indexes)
      @active.hand.check!(@hand_indexes)
      @partner.hand.check!(@partner_hand_indexes)
    end
  end
end
