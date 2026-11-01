module BeanBazaar
  module Bots
    # The middle level: plants, harvests and offers deals like SmartBot, but
    # trades more kindly. It makes few deals with the other bots, charges nothing
    # extra for helping the leader and takes more of the gifts it is offered, so
    # a good player wins about a fair share.
    class NormalBot < SmartBot
      # Any gift that does it some good is welcome.
      KIND_GIFT_VALUE = 1
      # Deals among themselves are what make bots strong. With two a turn, a good
      # player wins about a fair share in testing; with one, nearly every game.
      MAX_BOT_DEALS = 2

      private

      # Once it has made its deals this turn, spare cards go to the human instead.
      def offer(partner_indexes, face_up_indexes: [], hand_indexes: [])
        return super if deals_this_turn < MAX_BOT_DEALS

        # Only one offer can wait at a time; the giving stops until the human answers.
        @game.offer.nil? && gift_to_human(face_up_indexes, hand_indexes)
      end

      # Trades made since its turn began, read from the log.
      def deals_this_turn
        types = @game.log.reverse.map { |event| event_type(event) }
        types.take_while { |type| type != 'turn' }.count('trade')
      end

      # Saved log entries have string keys and fresh ones symbol keys.
      def event_type(event)
        (event[:type] || event['type']).to_s
      end

      def min_gift_value
        KIND_GIFT_VALUE
      end

      def help_cost
        HELP_COST
      end
    end
  end
end
