require 'bean_bazaar'

RSpec.describe BeanBazaar::Game do
  def player(name, hand)
    BeanBazaar::Player.new(name: name, hand: BeanBazaar::Hand.new(hand))
  end

  def texts(game)
    game.log.map { |entry| entry[:text] }
  end

  let(:calvin) { player('Calvin', %i[blue soy red]) }
  let(:bot) { player('Bot', %i[wax chili]) }
  let(:deck) { BeanBazaar::Deck.new(draw_pile: %i[green stink red red red black_eyed]) }
  let(:game) { described_class.new(players: [calvin, bot], deck: deck) }

  describe '.start' do
    it 'deals 5 cards to each of 3 to 5 players' do
      game = described_class.start(names: %w[Calvin Bot1 Bot2 Bot3], random: Random.new(1))

      expect(game.players.map { |player| player.hand.size }).to all(eq(5))
      expect(game.deck.draw_pile.size).to eq(104 - 20)
      expect(game.phase).to eq(:plant)
      expect(game.active_player.name).to eq('Calvin')
    end

    it 'lists the beans for its player count, plus any already in its cards' do
      small = described_class.start(names: %w[Calvin Bot1 Bot2], random: Random.new(1))
      calvin.hand.add(%i[coffee])

      expect(small.bean_types.map(&:key)).not_to include(:coffee, :golden)
      expect(game.bean_types.map(&:key)).to include(:coffee)
      expect(game.bean_types.map(&:key)).not_to include(:golden)
    end

    it 'rejects too few or too many players' do
      expect { described_class.start(names: %w[Calvin Bot]) }.to raise_error(ArgumentError, 'Bean Bazaar needs 3..5 players')
      expect { described_class.start(names: %w[A B C D E F]) }.to raise_error(ArgumentError)
    end
  end

  describe 'phase 1: planting from hand' do
    it 'plants the front card, then optionally the second' do
      game.plant_from_hand(0)

      expect(game.phase).to eq(:plant)

      game.plant_from_hand(1)

      expect(calvin.fields.map(&:bean)).to eq(%i[blue soy])
      expect(calvin.hand.cards).to eq(%i[red])
    end

    it 'flips straight away after the second card and refuses a third' do
      game.plant_from_hand(0)
      game.plant_from_hand(1)

      expect(game.phase).to eq(:trade)
      expect(game.face_up.cards).to eq(%i[green stink])
      expect { game.plant_from_hand(0) }.to raise_error(BeanBazaar::IllegalMove, 'You can plant at most 2 cards from your hand')
    end

    it 'flips straight away when the first plant empties the hand' do
      calvin.hand.take_all
      calvin.hand.add(%i[blue])
      game.plant_from_hand(0)

      expect(game.phase).to eq(:trade)
      expect(game.face_up.cards).to eq(%i[green stink])
    end

    it "keeps the card in hand when the field doesn't fit" do
      calvin.plant(:wax, 0)

      expect { game.plant_from_hand(0) }.to raise_error(BeanBazaar::IllegalMove)
      expect(calvin.hand.cards).to eq(%i[blue soy red])
    end

    it 'requires the first plant before flipping' do
      expect { game.flip_cards }.to raise_error(BeanBazaar::IllegalMove, 'Plant the front card of your hand first')
    end

    it 'lets an empty hand flip straight away' do
      calvin.hand.take_all
      game.flip_cards

      expect(game.phase).to eq(:trade)
    end

    it 'rejects planting from an empty hand' do
      calvin.hand.take_all

      expect { game.plant_from_hand(0) }.to raise_error(BeanBazaar::IllegalMove, 'Your hand is empty')
    end
  end

  describe 'phase 2: trading' do
    before do
      game.plant_from_hand(0)
      game.flip_cards
    end

    it 'flips 2 cards face up' do
      expect(game.face_up.cards).to eq(%i[green stink])
    end

    it 'trades between the active player and a partner' do
      game.trade(partner_index: 1, face_up_indexes: [0], partner_hand_indexes: [1])

      expect(bot.pending).to eq(%i[green])
      expect(calvin.pending).to eq(%i[chili])
    end

    it "keeps traded beans out of further trades until they're planted" do
      game.trade(partner_index: 1, face_up_indexes: [0], partner_hand_indexes: [1])

      expect(calvin.hand.cards).to eq(%i[soy red])
      expect(bot.hand.cards).to eq(%i[wax])
      expect { game.trade(partner_index: 1, hand_indexes: [2]) }.to raise_error(BeanBazaar::IllegalMove)
      expect { game.trade(partner_index: 1, partner_hand_indexes: [1]) }.to raise_error(BeanBazaar::IllegalMove)
      expect(calvin.pending).to eq(%i[chili])
      expect(bot.pending).to eq(%i[green])
    end

    it 'rejects an unknown partner' do
      expect { game.trade(partner_index: 5, hand_indexes: [0]) }.to raise_error(BeanBazaar::IllegalMove, 'There is no player 5')
    end

    it 'gives untraded face-up cards to the active player' do
      game.end_trading

      expect(calvin.pending).to eq(%i[green stink])
      expect(game.phase).to eq(:plant_pending)
    end

    it 'blocks planting from hand' do
      expect { game.plant_from_hand(1) }.to raise_error(BeanBazaar::IllegalMove, "You can't do that during the trade phase")
    end
  end

  describe 'phase 3 and 4: planting pending cards, then drawing' do
    before do
      game.plant_from_hand(0)
      game.flip_cards
      game.trade(partner_index: 1, face_up_indexes: [0])
      game.end_trading
    end

    it 'waits until every pending card is planted' do
      game.plant_pending(player_index: 0, pending_index: 0, field_index: 1)

      expect(game.phase).to eq(:plant_pending)
    end

    it 'draws 3 to the back of the hand and passes the turn' do
      game.plant_pending(player_index: 0, pending_index: 0, field_index: 1)
      game.plant_pending(player_index: 1, pending_index: 0, field_index: 0)

      expect(calvin.hand.cards).to eq(%i[soy red red red red])
      expect(game.active_player).to eq(bot)
      expect(game.phase).to eq(:plant)
      expect(game.hand_plants).to eq(0)
    end
  end

  it 'skips phase 3 when nothing is pending' do
    calvin.hand.take_all
    game.flip_cards
    game.trade(partner_index: 1, face_up_indexes: [0, 1])
    bot.pending.clear
    game.end_trading

    expect(game.active_player).to eq(bot)
  end

  describe 'harvesting and buying a field' do
    it 'works in any phase and discards the non-coin cards' do
      4.times { calvin.plant(:blue, 0) }
      game.harvest(player_index: 0, field_index: 0)

      expect(calvin.coins).to eq(1)
      expect(deck.discard_pile).to eq(%i[blue blue blue])
      expect(texts(game).last).to eq('Calvin harvested 4 Blue for 1 coin')
    end

    it 'discards the coins spent on a third field' do
      calvin.coin_cards.concat(%i[soy soy soy])
      game.buy_third_field(player_index: 0)

      expect(calvin.fields.size).to eq(3)
      expect(deck.discard_pile).to eq(%i[soy soy soy])
    end
  end

  describe 'the end of the game' do
    let(:deck) { BeanBazaar::Deck.new(draw_pile: %i[green], discard_pile: [], run_outs: 2) }

    before do
      calvin.plant(:soy, 1)
      calvin.plant(:soy, 1)
      game.plant_from_hand(0)
      game.flip_cards
    end

    it 'ends when the deck runs out the third time' do
      expect(game).to be_over
    end

    it 'harvests every field and clears the table' do
      expect(calvin.fields).to all(be_empty)
      expect(calvin.coins).to eq(1)
      expect(game.face_up).to be_empty
    end

    it 'names the player with the most coins' do
      expect(game.winners).to eq([calvin])
    end

    it 'breaks a tie on coins by cards left in hand' do
      tied = %w[Ann Bea].map { |name| BeanBazaar::Player.new(name: name, hand: BeanBazaar::Hand.new, coin_cards: %i[red]) }
      tied.last.hand.add(%i[soy])
      over = described_class.new(players: tied, deck: BeanBazaar::Deck.new(draw_pile: []), phase: :over)

      expect(over.winners).to eq([tied.last])
    end

    it 'logs a final harvest for each player with beans left, before the game over note' do
      expect(texts(game).last(2)).to eq(['Calvin earned 1 coin in the final harvest', 'The deck ran out for the third time. Game over!'])
      expect(game.log[-2]).to include(type: :final_harvest, player: 0)
    end

    it 'blocks further moves' do
      expect { game.harvest(player_index: 0, field_index: 0) }.to raise_error(BeanBazaar::IllegalMove, 'The game is over')
      expect { game.buy_third_field(player_index: 0) }.to raise_error(BeanBazaar::IllegalMove, 'The game is over')
    end
  end

  it 'ends when the draw at the end of a turn exhausts the deck' do
    deck = BeanBazaar::Deck.new(draw_pile: %i[green stink red], run_outs: 2)
    game = described_class.new(players: [calvin, bot], deck: deck)
    game.plant_from_hand(0)
    game.flip_cards
    game.trade(partner_index: 1, face_up_indexes: [0, 1])
    bot.pending.clear
    game.end_trading

    expect(game).to be_over
  end

  describe 'the game log' do
    it 'describes planting, flipping, trading and keeping' do
      game.plant_from_hand(0)
      game.flip_cards
      game.trade(partner_index: 1, face_up_indexes: [0], partner_hand_indexes: [1])
      game.trade(partner_index: 1, partner_hand_indexes: [0])
      game.end_trading

      expect(texts(game)).to eq([
        'Calvin planted Blue',
        'Calvin flipped Green and Stink',
        'Calvin traded Green to Bot for Chili',
        'Bot gave Wax to Calvin',
        'Calvin kept Stink',
      ])
    end

    it 'describes gifts, harvests, field purchases and turn changes' do
      game.plant_from_hand(0)
      game.flip_cards
      game.trade(partner_index: 1, face_up_indexes: [0, 1])
      bot.pending.clear
      calvin.coin_cards.concat(%i[red red red])
      game.buy_third_field(player_index: 0)
      game.harvest(player_index: 0, field_index: 0)
      game.end_trading

      expect(texts(game).last(4)).to eq([
        'Calvin gave Green and Stink to Bot',
        'Calvin bought a third field',
        'Calvin harvested 1 Blue for 0 coins',
        "Bot's turn",
      ])
    end

    it "rejects harvesting a field that doesn't exist" do
      expect { game.harvest(player_index: 0, field_index: 5) }.to raise_error(BeanBazaar::IllegalMove, 'There is no field 5')
    end

    it 'keeps only the latest entries' do
      old_entries = Array.new(60) { |index| { seq: index, text: "Entry #{index}" } }
      long_game = described_class.new(players: [calvin, bot], deck: deck, log: old_entries, event_seq: 60)
      long_game.plant_from_hand(0)

      expect(long_game.log.size).to eq(60)
      expect(long_game.log.last).to include(seq: 61, type: :plant, player: 0, text: 'Calvin planted Blue')
    end

    it 'snapshots the public table with every entry, hiding hands' do
      game.plant_from_hand(0)
      table = game.log.last[:table]

      expect(table[:players].first).to eq(hand_size: 2, coins: 0, fields: [{ bean: :blue, count: 1 }, { bean: nil, count: 0 }], pending: [])
      expect(table).to include(phase: :plant, active_index: 0, face_up: [])
      expect(table[:deck]).to eq(draw: 6, discard: 0, discard_top: [], run_outs: 0)
    end

    it 'notes the end of the game, even when the flip finds no cards' do
      game = described_class.new(players: [calvin, bot], deck: BeanBazaar::Deck.new(draw_pile: [], run_outs: 2))
      game.plant_from_hand(0)
      game.flip_cards

      expect(texts(game).last).to eq('The deck ran out for the third time. Game over!')
      expect(texts(game)).not_to include(a_string_starting_with('Calvin flipped'))
    end
  end

  describe 'offers' do
    before do
      game.plant_from_hand(0)
      game.flip_cards
    end

    it 'waits for the partner to accept, then trades the asked-for beans' do
      game.propose(partner_index: 1, face_up_indexes: [0], partner_beans: %w[chili])

      expect(game.offer).to eq('partner_index' => 1, 'face_up_indexes' => [0], 'hand_indexes' => [], 'partner_beans' => %w[chili], 'choices' => [])
      expect(texts(game).last).to eq('Calvin offers Bot Green for Chili')
      expect { game.end_trading }.to raise_error(BeanBazaar::IllegalMove, 'Answer the waiting offer first')

      game.accept_offer

      expect(game.offer).to be_nil
      expect(bot.pending).to eq(%i[green])
      expect(calvin.pending).to eq(%i[chili])
      expect(game.offers_this_turn).to eq(1)
    end

    it 'lets the partner pick any one of the choices' do
      game.propose(partner_index: 1, face_up_indexes: [0], choices: %w[soy chili])

      expect(texts(game).last).to eq('Calvin offers Bot Green for Soy or Chili')
      expect { game.accept_offer(bean: 'soy') }.to raise_error(BeanBazaar::IllegalMove, 'You have no Soy to give')
      expect { game.accept_offer(bean: 'wax') }.to raise_error(BeanBazaar::IllegalMove, 'Pick one of Soy or Chili to give')

      game.accept_offer(bean: 'chili')

      expect(calvin.pending).to eq(%i[chili])
      expect(bot.pending).to eq(%i[green])
    end

    it 'remembers which choices a partner lacked when they decline' do
      game.propose(partner_index: 1, face_up_indexes: [0], choices: %w[soy chili])
      game.decline_offer

      expect(game.lacking[1]).to eq(%i[soy])
      expect(game.declined?(partner_index: 1, face_up_indexes: [0], choices: %w[chili soy])).to be(true)
    end

    describe 'bidding' do
      # Calvin offers the Green; the bot makes its own offers instead.
      before do
        game.propose(partner_index: 1, face_up_indexes: [0], partner_beans: %w[chili])
        game.open_bids
      end

      it 'turns the offer down and waits for the bidder' do
        expect(game.offer).to be_nil
        expect(game.bidding).to eq(1)
        expect(game.declined?(partner_index: 1, face_up_indexes: [0], partner_beans: %w[chili])).to be(true)
        expect(described_class.from_h(JSON.parse(game.to_h.to_json)).bidding).to eq(1)
        expect { game.end_trading }.to raise_error(BeanBazaar::IllegalMove, 'Wait for the bids to finish')
      end

      it "trades the bidder's hand cards for face-up cards and beans from the active hand" do
        game.bid(face_up_indexes: [1], active_beans: %w[red], bidder_hand_indexes: [0])

        expect(bot.pending).to eq(%i[stink red])
        expect(calvin.pending).to eq(%i[wax])
        expect(texts(game).last).to eq('Calvin traded Stink and Red to Bot for Wax')
        expect { game.bid(active_beans: %w[blue]) }.to raise_error(BeanBazaar::IllegalMove, 'Calvin has no Blue to give')
      end

      it 'closes, and refuses bids once closed' do
        game.close_bids

        expect(game.bidding).to be_nil
        expect { game.bid(face_up_indexes: [0]) }.to raise_error(BeanBazaar::IllegalMove, 'Nobody is making offers right now')
      end
    end

    it 'can be declined, leaving the cards where they were' do
      game.propose(partner_index: 1, hand_indexes: [0])
      game.decline_offer

      expect(game.offer).to be_nil
      expect(calvin.hand.cards).to eq(%i[soy red])
      expect(texts(game).last).to eq("Bot turned down Calvin's offer")
    end

    it 'remembers a turned-down offer by its beans, even after a save' do
      game.propose(partner_index: 1, hand_indexes: [0], partner_beans: %w[chili])
      game.decline_offer

      expect(game.declined?(partner_index: 1, hand_indexes: [0], partner_beans: %w[chili])).to be(true)
      expect(game.declined?(partner_index: 1, hand_indexes: [1], partner_beans: %w[chili])).to be(false)
      expect(described_class.from_h(JSON.parse(game.to_h.to_json)).declined).to eq(game.declined)
    end

    it 'describes gifts and plain asks' do
      game.propose(partner_index: 1, face_up_indexes: [1])
      expect(texts(game).last).to eq('Calvin offers Bot Stink as a gift')
      game.decline_offer

      game.propose(partner_index: 1, partner_beans: %w[wax])
      expect(texts(game).last).to eq('Calvin asks Bot for Wax')
    end

    it 'fails to accept when the partner lacks the asked-for bean' do
      game.propose(partner_index: 1, face_up_indexes: [0], partner_beans: %w[soy])

      expect { game.accept_offer }.to raise_error(BeanBazaar::IllegalMove, 'You have no Soy to give')
      expect(game.offer).not_to be_nil
    end

    it 'rejects bad offers' do
      expect { game.propose(partner_index: 0, hand_indexes: [0]) }.to raise_error(BeanBazaar::IllegalMove, "You can't trade with yourself")
      expect { game.propose(partner_index: 1) }.to raise_error(BeanBazaar::IllegalMove, 'An offer needs at least one card')
      expect { game.propose(partner_index: 1, face_up_indexes: [5]) }.to raise_error(BeanBazaar::IllegalMove)
      expect { game.accept_offer }.to raise_error(BeanBazaar::IllegalMove, 'There is no offer to answer')
      expect { game.decline_offer }.to raise_error(BeanBazaar::IllegalMove, 'There is no offer to answer')
    end

    it 'blocks a second offer or a direct trade while one waits' do
      game.propose(partner_index: 1, hand_indexes: [0])

      expect { game.propose(partner_index: 1, hand_indexes: [1]) }.to raise_error(BeanBazaar::IllegalMove, 'Answer the waiting offer first')
      expect { game.trade(partner_index: 1, hand_indexes: [1]) }.to raise_error(BeanBazaar::IllegalMove, 'Answer the waiting offer first')
    end

    it 'remembers the beans a partner turned down an ask without holding' do
      game.propose(partner_index: 1, face_up_indexes: [0], partner_beans: %w[chili chili wax soy])
      game.decline_offer

      # Bot holds one chili and one wax, so only the second chili and the soy were missing.
      expect(game.lacking).to eq([[], %i[chili soy]])
    end

    it 'resets the offer count each turn' do
      game.propose(partner_index: 1, hand_indexes: [0])
      game.decline_offer
      game.trade(partner_index: 1, face_up_indexes: [0, 1])
      bot.pending.clear
      game.end_trading

      expect(game.offers_this_turn).to eq(0)
    end
  end

  describe 'saving and loading' do
    it 'forgets what a player lacks once they draw, and keeps it through a JSON round trip' do
      game = described_class.new(players: [calvin, bot], deck: deck, phase: :trade, hand_plants: 1, lacking: [%i[wax], %i[soy]])
      loaded = described_class.from_h(JSON.parse(JSON.generate(game.to_h)))
      expect(loaded.lacking).to eq([%i[wax], %i[soy]])

      game.end_trading

      expect(game.lacking).to eq([[], %i[soy]])
    end

    it 'survives a JSON round trip mid-turn' do
      game.plant_from_hand(0)
      game.flip_cards
      game.trade(partner_index: 1, face_up_indexes: [0])
      calvin.coin_cards.concat(%i[red])
      calvin.plant(:soy, 1)

      loaded = described_class.from_h(JSON.parse(JSON.generate(game.to_h)))

      expect(JSON.parse(JSON.generate(loaded.to_h))).to eq(JSON.parse(JSON.generate(game.to_h)))
      expect(loaded.phase).to eq(:trade)
      expect(loaded.players.last.pending).to eq(%i[green])
      expect(loaded.players.first.fields.map(&:bean)).to eq([:blue, :soy])
    end
  end

  it 'only names winners once the game is over' do
    expect { game.winners }.to raise_error(BeanBazaar::IllegalMove, "The game isn't over yet")
  end
end
