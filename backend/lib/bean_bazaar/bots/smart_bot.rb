module BeanBazaar
  module Bots
    # Plays to win. It reads its own hand order, cashes fields at payout steps
    # instead of harvesting them for nothing, values cards by how close they bring a
    # field to its next coin, and trades with the human as well as the other bots.
    class SmartBot < SimpleBot
      # How many cards past the front of the hand it plans around.
      LOOKAHEAD = 3
      # Deal scoring, in rough "points" where a coin is worth COIN_VALUE.
      COIN_VALUE = 3
      # A bean it plants towards a coin; a bean starting a fresh field is worth less.
      GROWING_BEAN_VALUE = 2
      NEW_FIELD_BEAN_VALUE = 1
      # Every bean the asker wants helps a rival, so a fair swap must pay for it.
      HELP_COST = 1

      def play_plant_phase
        buy_field_if_rich
        plant_front if !player.hand.empty?
        plant_front if wants_second_plant?
        return if @game.over?

        cash_in_full_fields
        @game.flip_cards if @game.phase == :plant
      end

      # Trades with the bots first, then makes one offer to the human per turn.
      # Returns early while that offer waits for an answer.
      def play_trade_phase(partner_indexes:, human_index: nil)
        offer_unwanted_cards(partner_indexes)
        return if propose_to_human(human_index)

        @game.end_trading
      end

      # Plants cards that already fit first, so any harvest frees the right field.
      def plant_pending
        while player.pending.any? && @game.phase == :plant_pending
          index = player.pending.index { |card| grows?(card) } || player.pending.index { |card| fits?(card) } || 0
          @game.plant_pending(player_index: @player_index, pending_index: index, field_index: field_for(player.pending[index]))
        end
      end

      # Takes a deal only when it comes out ahead, judging the deal as a whole:
      # where every offered bean would be planted, what it gives up, and how much
      # the asker gains. Junk gifts and one-sided swaps get turned down.
      def accepts?(offered:, requested:)
        deal_value(offered, requested).positive?
      end

      private

      # A third field pays off early, while there are reshuffles left to fill it.
      def buy_field_if_rich
        return if @game.deck.run_outs >= 2

        super
      end

      def wants_second_plant?
        card = player.hand.front
        return false if card.nil? || @game.hand_plants >= Game::MAX_HAND_PLANTS

        grows?(card) || (fits?(card) && !needed_soon_for_empty_field?(card))
      end

      # Keep an empty field free if a different upcoming card needs it more.
      def needed_soon_for_empty_field?(card)
        upcoming = player.hand.cards.drop(1).first(LOOKAHEAD)
        empty_fields = player.fields.count(&:empty?)
        others = upcoming.uniq.reject { |bean| bean == card || grows?(bean) }
        empty_fields <= others.size
      end

      # A field past its top payout gains nothing more, so sell it now. Such a field
      # always holds several beans, so the lone-bean rule never blocks it.
      def cash_in_full_fields
        player.fields.each_index do |index|
          field = player.fields[index]
          next if field.empty? || BeanType.find(field.bean).next_step(field.count)

          @game.harvest(player_index: @player_index, field_index: index)
        end
      end

      # Picks the field that loses least: high coins now, and no copies coming soon.
      def make_room
        field_index = harvestable_indexes.max_by { |index| harvest_score(player.fields[index]) }
        @game.harvest(player_index: @player_index, field_index: field_index)
        field_index
      end

      def harvest_score(field)
        coming = player.hand.cards.first(LOOKAHEAD + 1).count(field.bean)
        (field.coins * 10) - (coming * 6) - field.count
      end

      def deal_value(offered, requested)
        incoming_value(offered) - requested.sum { |card| keeping_value(card) } - (requested.size * HELP_COST)
      end

      # Plants the offered beans in its head: beans that grow a field come first,
      # each new bean type takes an empty field, then a field it must dig up.
      # Fields getting beans from this deal can't be dug up, so a deal with more
      # new types than it can place is refused outright.
      def incoming_value(cards)
        beans = cards.tally
        free_fields = player.fields.count(&:empty?) - fields_wanted_by_hand(cards)
        spare_fields = player.fields.reject { |field| field.empty? || beans.key?(field.bean) }.sort_by { |field| uprooting_cost(field) }
        beans.sort_by { |bean, count| [grows?(bean) ? 0 : 1, -count] }.sum do |bean, count|
          next growing_value(bean, count) if grows?(bean)
          next new_field_value(bean, count) if (free_fields -= 1) >= 0

          field = spare_fields.shift
          return -Float::INFINITY if field.nil?

          new_field_value(bean, count) - uprooting_cost(field)
        end
      end

      def growing_value(bean, count)
        field = player.fields.find { |candidate| candidate.bean == bean }
        type = BeanType.find(bean)
        coins_gained = type.coins_for(field.count + count) - type.coins_for(field.count)
        (count * GROWING_BEAN_VALUE) + (coins_gained * COIN_VALUE)
      end

      # A fresh field is worth more when its own hand is about to add to it.
      def new_field_value(bean, count)
        coming = player.hand.cards.first(LOOKAHEAD + 1).count(bean)
        ((count + coming) * NEW_FIELD_BEAN_VALUE) + (BeanType.find(bean).coins_for(count + coming) * COIN_VALUE)
      end

      # Digging up a field throws away the beans that haven't reached a coin yet.
      def uprooting_cost(field)
        COIN_VALUE + [field.count - (field.coins * COIN_VALUE), 0].max
      end

      # An empty field stays free for the front card, which must be planted next turn.
      # Reserving more than that turns down too many useful trades.
      def fields_wanted_by_hand(offered)
        front = player.hand.front
        front.nil? || grows?(front) || offered.include?(front) ? 0 : 1
      end

      # What a hand card is worth keeping: a bean it grows is valuable, a card with
      # nowhere to go is a relief to hand over.
      def keeping_value(card)
        return GROWING_BEAN_VALUE + 1 if grows?(card)
        return 0 if player.fields.any?(&:empty?)

        -1
      end

      # Gives the human a card it can't use and asks for the bean that brings its
      # best field closest to the next coin. False when it has nothing to offer.
      def propose_to_human(human_index)
        return false if human_index.nil? || @game.offers_this_turn.positive?

        face_up_index = @game.face_up.cards.index { |card| !grows?(card) }
        hand_index = face_up_index.nil? ? junk_hand_index : nil
        return false if face_up_index.nil? && hand_index.nil?

        @game.propose(
          partner_index: human_index,
          face_up_indexes: Array(face_up_index),
          hand_indexes: Array(hand_index),
          partner_beans: Array(wanted_bean),
        )
        true
      end

      # The last hand card that fits none of its fields: the one it would plant latest.
      def junk_hand_index
        player.hand.cards.rindex { |card| !fits?(card) }
      end

      def wanted_bean
        growing = player.fields.reject(&:empty?)
        best = growing.min_by { |field| BeanType.find(field.bean).next_step(field.count).to_i - field.count }
        best&.bean
      end
    end
  end
end
