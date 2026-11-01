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
      # Every bean the asker wants helps a rival, so a fair swap must pay for it,
      # and more so for every coin the asker is ahead, up to MAX_LEAD_COST.
      HELP_COST = 1
      MAX_LEAD_COST = 3
      # A gift fills a field, so it must be worth more than one lonely bean.
      MIN_GIFT_VALUE = 2
      # On its turn the human gets this many offers, never the same one twice. With
      # three, a player who trades like a bot wins as often from the human's seat
      # as from a bot's; with two, the bots' deals among themselves win out.
      MAX_OFFERS_TO_HUMAN = 3
      # A swap lists up to this many beans it would take, so the human can pick one they hold.
      MAX_CHOICES = 3

      def play_plant_phase
        buy_field_if_rich
        plant_front if !player.hand.empty?
        plant_front if wants_second_plant?
        return if @game.over?

        cash_in_full_fields
        @game.flip_cards if @game.phase == :plant
      end

      # Makes its offers to the human first, so the human sees the cards before the
      # bots share them out, then trades with the bots. Returns early while that
      # offer waits for an answer; the runner calls it again once it is settled.
      def play_trade_phase(partner_indexes:, human_index: nil)
        @human_index = human_index
        return if propose_to_human(human_index)

        offer_unwanted_cards(partner_indexes)
        offer_junk_hand(partner_indexes)
        @game.end_trading if @game.offer.nil?
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
        value = deal_value(offered, requested)
        requested.empty? ? value >= min_gift_value : value.positive?
      end

      # A smaller deal it would take instead: it drops whichever card helps it most,
      # one at a time, until the deal comes out ahead. When the asker wanted beans it
      # keeps at least one in, so a counter is never just "give me your card".
      # Nil when no smaller deal works.
      def counter_offer(offered:, requested:)
        must_give = !requested.empty?
        loop do
          options = offered.uniq.map { |card| [without_one(offered, card), requested] } +
            requested.uniq.map { |card| [offered, without_one(requested, card)] }
          options.reject! { |option_offered, option_requested| (must_give && option_requested.empty?) || option_offered.empty? && option_requested.empty? }
          return nil if options.empty?

          offered, requested = options.max_by { |option| deal_value(*option) }
          return { offered: offered, requested: requested } if accepts?(offered: offered, requested: requested)
        end
      end

      private

      # Gifts go to the poorest player, the human included. Cards no bot wants stay
      # with it rather than going to the human: in testing, that junk only clogged
      # the human's fields. A gift to the human waits for an answer, so the giving
      # stops until the human has replied.
      def offer(partner_indexes, face_up_indexes: [], hand_indexes: [])
        return false if @game.offer
        return true if human_poorest?(partner_indexes) && gift_to_human(face_up_indexes, hand_indexes)

        super
      end

      def human_poorest?(partner_indexes)
        return false if @human_index.nil?

        partner_indexes.all? { |index| @game.players[@human_index].coins <= @game.players[index].coins }
      end

      def gift_to_human(face_up_indexes, hand_indexes)
        return false if @human_index.nil? || @game.offers_this_turn >= MAX_OFFERS_TO_HUMAN

        gift = { partner_index: @human_index, face_up_indexes: face_up_indexes, hand_indexes: hand_indexes }
        return false if @game.declined?(**gift)

        @game.propose(**gift)
        true
      end

      def without_one(cards, card)
        cards.dup.tap { |rest| rest.delete_at(rest.index(card)) }
      end

      # Hands off hand cards it has no field for, so its next plants stay smooth.
      def offer_junk_hand(partner_indexes)
        loop do
          hand_index = junk_hand_index
          break if hand_index.nil? || !offer(partner_indexes, hand_indexes: [hand_index])
        end
      end

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
        incoming_value(offered) - requested.sum { |card| keeping_value(card) } - (requested.size * help_cost)
      end

      def min_gift_value
        MIN_GIFT_VALUE
      end

      # Helping a leader costs more.
      def help_cost
        lead = @game.players[asker_index].coins - player.coins
        HELP_COST + lead.clamp(0, MAX_LEAD_COST)
      end

      # The active player asks, unless this bot is active and someone is bidding to it.
      def asker_index
        @game.bidding && @player_index == @game.active_index ? @game.bidding : @game.active_index
      end

      # A flipped card that fits a free field is worth keeping: it must be planted
      # anyway, and giving it away only helps a rival.
      def unwanted_face_up_index
        keep = keepable_new_bean
        @game.face_up.cards.index { |card| !grows?(card) && card != keep }
      end

      # The one new bean it would start a field with, if a field is free for it.
      def keepable_new_bean
        free_fields = player.fields.count(&:empty?) - fields_wanted_by_hand([])
        return nil if !free_fields.positive?

        @game.face_up.cards.find { |card| !grows?(card) }
      end

      # Plants the offered beans in its head: beans that grow a field come first,
      # each new bean type takes an empty field, then a field it must dig up.
      # Fields getting beans from this deal can't be dug up, so a deal with more
      # new types than it can place is refused outright.
      def incoming_value(cards)
        beans = cards.tally
        free_fields = player.fields.count(&:empty?) - fields_wanted_by_hand(cards)
        spare_fields = uprootable_fields(beans)
        beans.sort_by { |bean, count| [grows?(bean) ? 0 : 1, -count] }.sum do |bean, count|
          next growing_value(bean, count) if grows?(bean)
          next new_field_value(bean, count) if (free_fields -= 1) >= 0

          field = spare_fields.shift
          return -Float::INFINITY if field.nil?

          new_field_value(bean, count) - uprooting_cost(field)
        end
      end

      # The fields it could dig up for a new bean, in the order make_room would pick
      # them, so the plan and the harvest agree.
      def uprootable_fields(beans)
        harvestable_indexes.map { |index| player.fields[index] }
          .reject { |field| field.empty? || beans.key?(field.bean) }
          .sort_by { |field| -harvest_score(field) }
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

      # Gives the human a card it can't use for any one of the beans it grows, or,
      # once that was turned down, offers it as a gift. False when it has nothing
      # new to offer.
      def propose_to_human(human_index)
        return false if human_index.nil? || @game.offers_this_turn >= MAX_OFFERS_TO_HUMAN

        offer = offers_for_human(human_index).find { |candidate| !@game.declined?(**candidate) }
        return false if offer.nil?

        @game.propose(**offer)
        true
      end

      # The swap, then the same cards as a gift.
      def offers_for_human(human_index)
        face_up_index = unwanted_face_up_index
        hand_index = face_up_index.nil? ? junk_hand_index : nil
        return [] if face_up_index.nil? && hand_index.nil?

        cards = Array(face_up_index).map { |index| @game.face_up.cards[index] } + Array(hand_index).map { |index| player.hand.cards[index] }
        choices = (wanted_beans(human_index) - turned_down_choices(human_index, cards)).first(MAX_CHOICES)
        [choices, []].uniq.map do |offered_choices|
          { partner_index: human_index, face_up_indexes: Array(face_up_index), hand_indexes: Array(hand_index), choices: offered_choices }
        end
      end

      # Beans the human already refused to give for these same cards this turn.
      def turned_down_choices(human_index, cards)
        gives = cards.map(&:to_s).sort
        @game.declined
          .select { |record| record['partner_index'] == human_index && record['gives'] == gives }
          .flat_map { |record| record.fetch('choices', []).map(&:to_sym) }
      end

      # The last hand card that fits none of its fields: the one it would plant latest.
      def junk_hand_index
        player.hand.cards.rindex { |card| !fits?(card) }
      end

      def wanted_bean(partner_index)
        wanted_beans(partner_index).first
      end

      # The beans it grows, the one closest to its next coin first, skipping beans
      # the partner has already said they hold none of.
      def wanted_beans(partner_index)
        player.fields
          .reject { |field| field.empty? || @game.lacking[partner_index].include?(field.bean) }
          .each_with_index.sort_by { |field, index| [BeanType.find(field.bean).next_step(field.count).to_i - field.count, index] }
          .map { |field, _index| field.bean }.uniq
      end
    end
  end
end
