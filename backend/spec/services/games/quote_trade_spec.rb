require 'rails_helper'

RSpec.describe Games::QuoteTrade do
  def field(bean = nil, count = 0)
    BeanBazaar::Field.new(bean: bean, count: count)
  end

  def player(name, hand, fields: [field, field])
    BeanBazaar::Player.new(name: name, hand: BeanBazaar::Hand.new(hand), fields: fields)
  end

  # Pinto grows red and holds a spare green; Lima grows wax and soy and holds two wax.
  let(:you) { player('You', %i[blue soy]) }
  let(:pinto) { player('Pinto', %i[green stink], fields: [field(:red, 2), field]) }
  let(:lima) { player('Lima', %i[wax wax], fields: [field(:wax, 2), field(:soy, 3)]) }
  let(:engine) do
    BeanBazaar::Game.new(
      players: [you, pinto, lima],
      deck: BeanBazaar::Deck.new(draw_pile: Array.new(20, :chili)),
      phase: :trade,
      face_up: BeanBazaar::Hand.new(%i[red soy]),
    )
  end
  let(:game) { Game.create!(state: engine.to_h, bot_level: 'smart') }

  def answers(**quote)
    described_class.new(game, quote).call[:payload][:answers].to_h { |entry| [entry[:player], entry[:answer]] }
  end

  it 'asks every bot without trading anything' do
    result = answers(face_up_indexes: [0], partner_beans: ['green'])

    expect(result).to eq(1 => 'accept', 2 => 'missing')
    expect(game.reload.state).to eq(JSON.parse(JSON.generate(engine.to_h)))
  end

  it 'reports a bot that would rather keep its beans' do
    expect(answers(hand_indexes: [0], partner_beans: ['wax'])).to eq(1 => 'missing', 2 => 'decline')
  end

  it 'quotes a gift to every bot, each judging it for itself' do
    # Shrewd Lima takes the soy that reaches its next coin; Pinto keeps its one empty
    # field for the green it plants next.
    expect(answers(face_up_indexes: [1])).to eq(1 => 'decline', 2 => 'accept')
  end

  it 'passes on the smaller deal a declining bot would take instead' do
    # Two soy aren't worth both of Lima's wax, but they are worth one.
    result = described_class.new(game, face_up_indexes: [1], hand_indexes: [1], partner_beans: %w[wax wax]).call[:payload][:answers]

    expect(result).to include(player: 2, answer: 'decline', counter: { give: %w[soy soy], ask: %w[wax] })
  end

  describe 'while you bid on a bot turn' do
    # Pinto is trading its flipped red and soy; you made your own offer instead of its deal.
    let(:you) { player('You', %i[red blue]) }
    let(:engine) do
      BeanBazaar::Game.new(
        players: [you, pinto, lima],
        deck: BeanBazaar::Deck.new(draw_pile: Array.new(20, :chili)),
        phase: :trade,
        active_index: 1,
        face_up: BeanBazaar::Hand.new(%i[red soy]),
        bidding: 0,
      )
    end

    it 'asks only the active bot, judging your hand cards for its cards' do
      # Your red grows Pinto's red field; its own red it keeps.
      expect(answers(hand_indexes: [0], face_up_indexes: [1])).to eq(1 => 'accept')
      expect(answers(hand_indexes: [1], face_up_indexes: [0])).to eq(1 => 'decline')
      expect(answers(hand_indexes: [0], partner_beans: ['wax'])).to eq(1 => 'missing')
    end
  end

  it "only quotes during the human's trade phase" do
    game.update!(state: engine.to_h.merge(phase: :plant))
    result = described_class.new(game, face_up_indexes: [0]).call

    expect(result).to include(success: false)
    expect(result[:extra_params][:alert]).to eq('Wait for your turn')
  end

  it 'rejects bad card positions' do
    expect(described_class.new(game, face_up_indexes: [9]).call[:extra_params][:alert]).to eq('There is no card at position 9')
    expect(described_class.new(game, hand_indexes: ['x']).call[:extra_params][:alert]).to eq('hand_indexes must be a list of numbers')
  end

  it 'falls back to a general alert for anything unexpected' do
    allow(game).to receive(:engine).and_raise(ActiveRecord::RecordInvalid.new(game))

    expect(described_class.new(game, {}).call[:extra_params][:alert]).to eq("The bots couldn't answer, please try again")
  end
end
