module BeanBazaar
  module Bots
    # Plays by simple rules: plant where a card fits, keep beans that match its
    # fields, give away the rest, and harvest the best field when it needs room.
    # This is the "easy" bot; SmartBot builds on it. BotRunner only calls the
    # public methods below.
    class SimpleBot
      def initialize(game, player_index)
        @game = game
        @player_index = player_index
      end

      def play_plant_phase
        plant_front if !player.hand.empty?
        plant_front if wants_second_plant?
        return if @game.over?

        buy_field_if_rich
        @game.flip_cards if @game.phase == :plant
      end

      # Offers face-up cards it can't use to other bots, then ends trading.
      # The easy bot never makes offers to the human.
      def play_trade_phase(partner_indexes:, human_index: nil) # rubocop:disable Lint/UnusedMethodArgument
        offer_unwanted_cards(partner_indexes)
        @game.end_trading
      end

      def plant_pending
        while player.pending.any? && @game.phase == :plant_pending
          @game.plant_pending(player_index: @player_index, pending_index: 0, field_index: field_for(player.pending.first))
        end
      end

      # As a trade partner: take cards it can plant, never give away a bean it grows.
      def accepts?(offered:, requested:)
        offered.all? { |card| fits?(card) } && requested.none? { |card| grows?(card) }
      end

      def grows?(card)
        player.fields.any? { |field| field.bean == card }
      end

      private

      def player
        @game.players[@player_index]
      end

      def plant_front
        @game.plant_from_hand(field_for(player.hand.front))
      end

      def wants_second_plant?
        card = player.hand.front
        @game.hand_plants < Game::MAX_HAND_PLANTS && !card.nil? && fits?(card)
      end

      def fits?(card)
        player.fields.any? { |field| field.accepts?(card) }
      end

      def buy_field_if_rich
        return if player.fields.size >= Player::MAX_FIELDS
        return if player.coins < Player::THIRD_FIELD_PRICE

        @game.buy_third_field(player_index: @player_index)
      end

      # Same bean first, then an empty field, otherwise harvest to make room.
      def field_for(card)
        matching = player.fields.index { |field| field.bean == card }
        return matching if matching

        player.fields.index(&:empty?) || make_room
      end

      def make_room
        field_index = harvestable_indexes.max_by { |index| [player.fields[index].coins, -player.fields[index].count] }
        @game.harvest(player_index: @player_index, field_index: field_index)
        field_index
      end

      def harvestable_indexes
        crowded = player.fields.any? { |field| field.count > 1 }
        player.fields.each_index.reject { |index| crowded && player.fields[index].count == 1 }
      end

      def offer_unwanted_cards(partner_indexes)
        loop do
          face_up_index = @game.face_up.cards.index { |card| !grows?(card) }
          break if face_up_index.nil?
          break if !offer(face_up_index, partner_indexes)
        end
      end

      # Tries a swap for a bean it grows, then a plain gift. False if nobody wants it.
      def offer(face_up_index, partner_indexes)
        card = @game.face_up.cards[face_up_index]

        partner_indexes.each do |partner_index|
          partner = self.class.new(@game, partner_index)
          wanted_index = @game.players[partner_index].hand.cards.index { |hand_card| grows?(hand_card) }
          requested = wanted_index.nil? ? [] : [@game.players[partner_index].hand.cards[wanted_index]]
          next if !partner.accepts?(offered: [card], requested: requested)

          @game.trade(partner_index: partner_index, face_up_indexes: [face_up_index], partner_hand_indexes: Array(wanted_index))
          return true
        end
        false
      end
    end
  end
end
