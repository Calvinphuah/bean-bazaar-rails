require "bean_bazaar"

RSpec.describe BeanBazaar::Game do
  def player(name, hand)
    BeanBazaar::Player.new(name: name, hand: BeanBazaar::Hand.new(hand))
  end

  let(:calvin) { player("Calvin", %i[blue soy red]) }
  let(:bot) { player("Bot", %i[wax chili]) }
  let(:deck) { BeanBazaar::Deck.new(draw_pile: %i[green stink red red red black_eyed]) }
  let(:game) { described_class.new(players: [ calvin, bot ], deck: deck) }

  describe ".start" do
    it "deals 5 cards to each of 3 to 5 players" do
      game = described_class.start(names: %w[Calvin Bot1 Bot2 Bot3], random: Random.new(1))

      expect(game.players.map { |player| player.hand.size }).to all(eq(5))
      expect(game.deck.draw_pile.size).to eq(104 - 20)
      expect(game.phase).to eq(:plant)
      expect(game.active_player.name).to eq("Calvin")
    end

    it "rejects too few or too many players" do
      expect { described_class.start(names: %w[Calvin Bot]) }.to raise_error(ArgumentError, "Bean Bazaar needs 3..5 players")
      expect { described_class.start(names: %w[A B C D E F]) }.to raise_error(ArgumentError)
    end
  end

  describe "phase 1: planting from hand" do
    it "plants the front card, then optionally the second" do
      game.plant_from_hand(0)
      game.plant_from_hand(1)

      expect(calvin.fields.map(&:bean)).to eq(%i[blue soy])
      expect(calvin.hand.cards).to eq(%i[red])
    end

    it "stops after two cards" do
      game.plant_from_hand(0)
      game.plant_from_hand(1)

      expect { game.plant_from_hand(0) }.to raise_error(BeanBazaar::IllegalMove, "You can plant at most 2 cards from your hand")
    end

    it "keeps the card in hand when the field doesn't fit" do
      calvin.plant(:wax, 0)

      expect { game.plant_from_hand(0) }.to raise_error(BeanBazaar::IllegalMove)
      expect(calvin.hand.cards).to eq(%i[blue soy red])
    end

    it "requires the first plant before flipping" do
      expect { game.flip_cards }.to raise_error(BeanBazaar::IllegalMove, "Plant the front card of your hand first")
    end

    it "lets an empty hand flip straight away" do
      calvin.hand.take_all
      game.flip_cards

      expect(game.phase).to eq(:trade)
    end

    it "rejects planting from an empty hand" do
      calvin.hand.take_all

      expect { game.plant_from_hand(0) }.to raise_error(BeanBazaar::IllegalMove, "Your hand is empty")
    end
  end

  describe "phase 2: trading" do
    before do
      game.plant_from_hand(0)
      game.flip_cards
    end

    it "flips 2 cards face up" do
      expect(game.face_up.cards).to eq(%i[green stink])
    end

    it "trades between the active player and a partner" do
      game.trade(partner_index: 1, face_up_indexes: [ 0 ], partner_hand_indexes: [ 1 ])

      expect(bot.pending).to eq(%i[green])
      expect(calvin.pending).to eq(%i[chili])
    end

    it "rejects an unknown partner" do
      expect { game.trade(partner_index: 5, hand_indexes: [ 0 ]) }.to raise_error(BeanBazaar::IllegalMove, "There is no player 5")
    end

    it "gives untraded face-up cards to the active player" do
      game.end_trading

      expect(calvin.pending).to eq(%i[green stink])
      expect(game.phase).to eq(:plant_pending)
    end

    it "blocks planting from hand" do
      expect { game.plant_from_hand(1) }.to raise_error(BeanBazaar::IllegalMove, "You can't do that during the trade phase")
    end
  end

  describe "phase 3 and 4: planting pending cards, then drawing" do
    before do
      game.plant_from_hand(0)
      game.flip_cards
      game.trade(partner_index: 1, face_up_indexes: [ 0 ])
      game.end_trading
    end

    it "waits until every pending card is planted" do
      game.plant_pending(player_index: 0, pending_index: 0, field_index: 1)

      expect(game.phase).to eq(:plant_pending)
    end

    it "draws 3 to the back of the hand and passes the turn" do
      game.plant_pending(player_index: 0, pending_index: 0, field_index: 1)
      game.plant_pending(player_index: 1, pending_index: 0, field_index: 0)

      expect(calvin.hand.cards).to eq(%i[soy red red red red])
      expect(game.active_player).to eq(bot)
      expect(game.phase).to eq(:plant)
      expect(game.hand_plants).to eq(0)
    end
  end

  it "skips phase 3 when nothing is pending" do
    calvin.hand.take_all
    game.flip_cards
    game.trade(partner_index: 1, face_up_indexes: [ 0, 1 ])
    bot.pending.clear
    game.end_trading

    expect(game.active_player).to eq(bot)
  end

  describe "harvesting and buying a field" do
    it "works in any phase and discards the non-coin cards" do
      4.times { calvin.plant(:blue, 0) }
      game.harvest(player_index: 0, field_index: 0)

      expect(calvin.coins).to eq(1)
      expect(deck.discard_pile).to eq(%i[blue blue blue])
    end

    it "discards the coins spent on a third field" do
      calvin.coin_cards.concat(%i[soy soy soy])
      game.buy_third_field(player_index: 0)

      expect(calvin.fields.size).to eq(3)
      expect(deck.discard_pile).to eq(%i[soy soy soy])
    end
  end

  describe "the end of the game" do
    let(:deck) { BeanBazaar::Deck.new(draw_pile: %i[green], discard_pile: [], run_outs: 2) }

    before do
      calvin.plant(:soy, 1)
      calvin.plant(:soy, 1)
      game.plant_from_hand(0)
      game.flip_cards
    end

    it "ends when the deck runs out the third time" do
      expect(game).to be_over
    end

    it "harvests every field and clears the table" do
      expect(calvin.fields).to all(be_empty)
      expect(calvin.coins).to eq(1)
      expect(game.face_up).to be_empty
    end

    it "names the player with the most coins" do
      expect(game.winners).to eq([ calvin ])
    end

    it "blocks further moves" do
      expect { game.harvest(player_index: 0, field_index: 0) }.to raise_error(BeanBazaar::IllegalMove, "The game is over")
      expect { game.buy_third_field(player_index: 0) }.to raise_error(BeanBazaar::IllegalMove, "The game is over")
    end
  end

  it "ends when the draw at the end of a turn exhausts the deck" do
    deck = BeanBazaar::Deck.new(draw_pile: %i[green stink red], run_outs: 2)
    game = described_class.new(players: [ calvin, bot ], deck: deck)
    game.plant_from_hand(0)
    game.flip_cards
    game.trade(partner_index: 1, face_up_indexes: [ 0, 1 ])
    bot.pending.clear
    game.end_trading

    expect(game).to be_over
  end

  it "only names winners once the game is over" do
    expect { game.winners }.to raise_error(BeanBazaar::IllegalMove, "The game isn't over yet")
  end
end
