require "rails_helper"

RSpec.describe Games::MoveService do
  def field(bean = nil, count = 0)
    BeanBazaar::Field.new(bean: bean, count: count)
  end

  def player(name, hand, fields: [ field, field ], coin_cards: [])
    BeanBazaar::Player.new(name: name, hand: BeanBazaar::Hand.new(hand), fields: fields, coin_cards: coin_cards)
  end

  # You hold blue/soy; Pinto grows red and will swap away a spare soy; Lima grows wax.
  let(:you) { player("You", %i[blue soy chili]) }
  let(:pinto) { player("Pinto", %i[green stink], fields: [ field(:red, 2), field ]) }
  let(:lima) { player("Lima", %i[wax], fields: [ field(:wax, 2), field(:soy, 2) ]) }
  let(:deck) { BeanBazaar::Deck.new(draw_pile: %i[red soy] + Array.new(40, :chili)) }
  let(:engine) { BeanBazaar::Game.new(players: [ you, pinto, lima ], deck: deck) }
  let(:game) { Game.create!(state: engine.to_h) }

  def move(type, **fields)
    described_class.new(game: game, move: { type: type, **fields }).call.engine
  end

  it "plants from hand and saves the game" do
    result = move("plant_from_hand", field_index: 0)

    expect(result.players.first.fields.first.bean).to eq(:blue)
    expect(game.reload.engine.hand_plants).to eq(1)
  end

  it "flips cards into the trade phase" do
    move("plant_from_hand", field_index: 0)

    expect(move("flip_cards").face_up.cards).to eq(%i[red soy])
  end

  describe "trading" do
    # A spare third field leaves room for the face-up red bean.
    let(:you) { player("You", %i[blue soy chili], fields: [ field, field, field ]) }

    before do
      move("plant_from_hand", field_index: 0)
      move("plant_from_hand", field_index: 1)
      move("flip_cards")
    end

    it "trades with a bot that likes the offer" do
      result = move("trade", partner_index: 1, face_up_indexes: [ 0 ], partner_beans: [ "green" ])

      expect(result.players[1].pending).to eq(%i[red])
      expect(result.players[0].pending).to eq(%i[green])
    end

    it "reports a bot turning the offer down" do
      expect { move("trade", partner_index: 2, partner_beans: [ "wax" ]) }
        .to raise_error(BeanBazaar::IllegalMove, "Lima turned down your offer")
    end

    it "rejects trading with yourself or nobody" do
      expect { move("trade", partner_index: 0, hand_indexes: [ 0 ]) }.to raise_error(BeanBazaar::IllegalMove, "You can't trade with yourself")
      expect { move("trade", partner_index: 9, hand_indexes: [ 0 ]) }.to raise_error(BeanBazaar::IllegalMove, "There is no player 9")
    end

    it "rejects a card that isn't there" do
      expect { move("trade", partner_index: 1, face_up_indexes: [ 7 ]) }.to raise_error(BeanBazaar::IllegalMove, "There is no card at position 7")
    end

    it "rejects asking for a bean the bot doesn't hold" do
      expect { move("trade", partner_index: 1, face_up_indexes: [ 0 ], partner_beans: %w[green green]) }
        .to raise_error(BeanBazaar::IllegalMove, "Pinto has no green bean to give")
    end

    it "ends trading, plants pending cards, and lets the bots play" do
      move("end_trading")
      result = move("plant_pending", pending_index: 0, field_index: 2)

      expect(result.players.first.pending).to eq(%i[soy])
      result = move("plant_pending", pending_index: 0, field_index: 1)

      expect(result.active_index).to eq(0)
      expect(result.phase).to eq(:plant)
    end
  end

  it "harvests and buys a third field for the human at any time" do
    you.plant(:soy, 1)
    you.plant(:soy, 1)
    you.coin_cards.concat(%i[red red red])

    move("harvest", field_index: 1)
    result = move("buy_third_field")

    expect(result.players.first.coins).to eq(1)
    expect(result.players.first.fields.size).to eq(3)
  end

  it "blocks active-player moves on a bot's turn" do
    game.update!(state: engine.to_h.merge(active_index: 1))

    expect { move("flip_cards") }.to raise_error(BeanBazaar::IllegalMove, "Wait for your turn")
  end

  it "rejects unknown moves and bad numbers" do
    expect { move("cheat") }.to raise_error(BeanBazaar::IllegalMove, "Unknown move: cheat")
    expect { move("plant_from_hand", field_index: "left") }.to raise_error(BeanBazaar::IllegalMove, "field_index must be a number")
    expect { move("trade", partner_index: 1, hand_indexes: [ "x" ]) }
      .to raise_error(BeanBazaar::IllegalMove, "hand_indexes must be a list of numbers")
  end
end
