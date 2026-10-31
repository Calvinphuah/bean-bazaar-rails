require 'rails_helper'

RSpec.describe Games::MakeMove do
  def field(bean = nil, count = 0)
    BeanBazaar::Field.new(bean: bean, count: count)
  end

  def player(name, hand, fields: [field, field], coin_cards: [])
    BeanBazaar::Player.new(name: name, hand: BeanBazaar::Hand.new(hand), fields: fields, coin_cards: coin_cards)
  end

  # You hold blue/soy; Pinto grows red and will swap away a spare green; Lima grows wax and soy.
  let(:you) { player('You', %i[blue soy chili]) }
  let(:pinto) { player('Pinto', %i[green stink], fields: [field(:red, 2), field]) }
  let(:lima) { player('Lima', %i[wax], fields: [field(:wax, 2), field(:soy, 2)]) }
  let(:deck) { BeanBazaar::Deck.new(draw_pile: %i[red soy] + Array.new(40, :chili)) }
  let(:engine) { BeanBazaar::Game.new(players: [you, pinto, lima], deck: deck) }
  let(:game) { Game.create!(state: engine.to_h) }

  def move(type, **fields)
    described_class.new(game, { type: type, **fields }).call
  end

  def saved
    game.reload.engine
  end

  def expect_alert(result, message)
    expect(result).to include(success: false)
    expect(result[:extra_params][:alert]).to eq(message)
  end

  it 'plants from hand and saves the game' do
    result = move('plant_from_hand', field_index: 0)

    expect(result).to include(success: true, root_name: :game, payload: game)
    expect(saved.players.first.fields.first.bean).to eq(:blue)
    expect(saved.hand_plants).to eq(1)
  end

  it 'flips cards into the trade phase' do
    move('plant_from_hand', field_index: 0)
    move('flip_cards')

    expect(saved.face_up.cards).to eq(%i[red soy])
  end

  it 'leaves the saved game unchanged when a move breaks a rule' do
    expect_alert(move('flip_cards'), 'Plant the front card of your hand first')
    expect(saved.to_h).to eq(engine.to_h)
  end

  describe 'trading' do
    # A spare third field leaves room for the face-up red bean.
    let(:you) { player('You', %i[blue soy chili], fields: [field, field, field]) }

    before do
      move('plant_from_hand', field_index: 0)
      move('plant_from_hand', field_index: 1)
      move('flip_cards')
    end

    it 'trades with a bot that likes the offer' do
      move('trade', partner_index: 1, face_up_indexes: [0], partner_beans: ['green'])

      expect(saved.players[1].pending).to eq(%i[red])
      expect(saved.players[0].pending).to eq(%i[green])
    end

    it 'reports a bot turning the offer down' do
      expect_alert(move('trade', partner_index: 2, partner_beans: ['wax']), 'Lima turned down your offer')
    end

    it 'rejects trading with yourself or nobody' do
      expect_alert(move('trade', partner_index: 0, hand_indexes: [0]), "You can't trade with yourself")
      expect_alert(move('trade', partner_index: 9, hand_indexes: [0]), 'There is no player 9')
    end

    it 'rejects a card that is not there' do
      expect_alert(move('trade', partner_index: 1, face_up_indexes: [7]), 'There is no card at position 7')
    end

    it "rejects asking for a bean the bot doesn't hold" do
      expect_alert(
        move('trade', partner_index: 1, face_up_indexes: [0], partner_beans: %w[green green]),
        'Pinto has no green bean to give',
      )
    end

    it 'ends trading, plants pending cards, and lets the bots play' do
      move('end_trading')
      move('plant_pending', pending_index: 0, field_index: 2)

      expect(saved.players.first.pending).to eq(%i[soy])

      move('plant_pending', pending_index: 0, field_index: 1)

      expect(saved.active_index).to eq(0)
      expect(saved.phase).to eq(:plant)
    end
  end

  it 'harvests and buys a third field for the human at any time' do
    you.plant(:soy, 1)
    you.plant(:soy, 1)
    you.coin_cards.concat(%i[red red red])

    move('harvest', field_index: 1)
    move('buy_third_field')

    expect(saved.players.first.coins).to eq(1)
    expect(saved.players.first.fields.size).to eq(3)
  end

  it "blocks active-player moves on a bot's turn" do
    game.update!(state: engine.to_h.merge(active_index: 1))

    expect_alert(move('flip_cards'), 'Wait for your turn')
  end

  it 'rejects unknown moves and bad numbers' do
    expect_alert(move('cheat'), 'Unknown move: cheat')
    expect_alert(move('plant_from_hand', field_index: 'left'), 'field_index must be a number')
    expect_alert(move('trade', partner_index: 1, hand_indexes: ['x']), 'hand_indexes must be a list of numbers')
  end

  it 'falls back to a general alert when a save fails' do
    allow(game).to receive(:store).and_raise(ActiveRecord::RecordInvalid.new(game))

    expect_alert(move('plant_from_hand', field_index: 0), "The move couldn't be saved, please try again")
  end
end
