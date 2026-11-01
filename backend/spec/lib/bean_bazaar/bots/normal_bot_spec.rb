require 'bean_bazaar'

RSpec.describe BeanBazaar::Bots::NormalBot do
  def field(bean = nil, count = 0)
    BeanBazaar::Field.new(bean: bean, count: count)
  end

  def player(name, hand, fields: [field, field], coin_cards: [])
    BeanBazaar::Player.new(name: name, hand: BeanBazaar::Hand.new(hand), fields: fields, coin_cards: coin_cards)
  end

  let(:deck) { BeanBazaar::Deck.new(draw_pile: Array.new(30, :chili)) }

  describe '#play_trade_phase' do
    it 'stops dealing with bots after two deals a turn' do
      bot = player('Bot', %i[soy], fields: [field(:soy, 2), field(:blue, 3)])
      human = player('You', [], coin_cards: %i[red])
      takers = Array.new(3) { |index| player("Taker#{index}", %i[red wax stink]) }
      game = BeanBazaar::Game.new(players: [bot, human, *takers], deck: deck, phase: :trade, face_up: BeanBazaar::Hand.new(%i[red wax stink]),
                                  offers_this_turn: 2)
      described_class.new(game, 0).play_trade_phase(partner_indexes: [2, 3, 4], human_index: 1)

      # The human has had their offers this turn, so the third card stays with the bot.
      expect(takers.sum { |taker| taker.pending.size }).to eq(2)
      expect(bot.pending.size).to eq(1)
      expect(game.offer).to be_nil
    end
  end

  describe '#accepts?' do
    let(:bot) { player('Bot', %i[soy], fields: [field(:soy, 3), field]) }

    it 'takes a lone gift a smart bot would turn down' do
      game = BeanBazaar::Game.new(players: [player('Asker', []), bot], deck: deck)

      expect(described_class.new(game, 1).accepts?(offered: %i[blue], requested: [])).to be(true)
      expect(BeanBazaar::Bots::SmartBot.new(game, 1).accepts?(offered: %i[blue], requested: [])).to be(false)
    end

    it 'helps a leader at the usual price' do
      game = BeanBazaar::Game.new(players: [player('Asker', [], coin_cards: %i[red red red]), bot], deck: deck)

      expect(described_class.new(game, 1).accepts?(offered: %i[soy], requested: %i[soy])).to be(true)
    end
  end
end
