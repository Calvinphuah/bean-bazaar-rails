require 'bean_bazaar'

RSpec.describe BeanBazaar::Bots::SimpleBot do
  def player(name, hand, fields: nil, coin_cards: [])
    fields ||= [BeanBazaar::Field.new, BeanBazaar::Field.new]
    BeanBazaar::Player.new(name: name, hand: BeanBazaar::Hand.new(hand), fields: fields, coin_cards: coin_cards)
  end

  let(:deck) { BeanBazaar::Deck.new(draw_pile: %i[green stink red red red]) }

  describe '#play_plant_phase' do
    it 'plants the front card, plants a second that fits, and flips' do
      game = BeanBazaar::Game.new(players: [player('Bot', %i[blue soy red]), player('Other', [])], deck: deck)
      described_class.new(game, 0).play_plant_phase

      expect(game.players.first.fields.map(&:bean)).to eq(%i[blue soy])
      expect(game.phase).to eq(:trade)
    end

    it 'harvests the most valuable field when nothing fits' do
      fields = [BeanBazaar::Field.new(bean: :red, count: 3), BeanBazaar::Field.new(bean: :soy, count: 2)]
      game = BeanBazaar::Game.new(players: [player('Bot', %i[blue], fields: fields), player('Other', [])], deck: deck)
      described_class.new(game, 0).play_plant_phase

      expect(game.players.first.fields.map(&:bean)).to eq(%i[blue soy])
      expect(game.players.first.coins).to eq(2)
    end

    it 'skips planting with an empty hand and buys a third field when it can' do
      game = BeanBazaar::Game.new(players: [player('Bot', [], coin_cards: %i[red red red]), player('Other', [])], deck: deck)
      described_class.new(game, 0).play_plant_phase

      expect(game.players.first.fields.size).to eq(3)
      expect(game.phase).to eq(:trade)
    end
  end

  describe '#play_trade_phase' do
    it 'swaps an unwanted face-up card for a bean it grows' do
      bot = player('Bot', [], fields: [BeanBazaar::Field.new(bean: :soy, count: 2), BeanBazaar::Field.new(bean: :blue, count: 2)])
      partner = player('Partner', %i[soy], fields: [BeanBazaar::Field.new(bean: :green, count: 1), BeanBazaar::Field.new])
      game = BeanBazaar::Game.new(players: [bot, partner], deck: deck, phase: :trade, face_up: BeanBazaar::Hand.new(%i[green blue]))
      described_class.new(game, 0).play_trade_phase(partner_indexes: [1])

      expect(partner.pending).to eq(%i[green])
      expect(bot.pending).to eq(%i[soy blue])
      expect(game.phase).to eq(:plant_pending)
    end

    it 'asks only for its own bean, so a partner holding another one just gets a gift' do
      bot = player('Bot', [], fields: [BeanBazaar::Field.new(bean: :soy, count: 2), BeanBazaar::Field.new(bean: :blue, count: 2)])
      partner = player('Partner', %i[blue])
      game = BeanBazaar::Game.new(players: [bot, partner], deck: deck, phase: :trade, face_up: BeanBazaar::Hand.new(%i[green]))
      described_class.new(game, 0).play_trade_phase(partner_indexes: [1])

      expect(partner.hand.cards).to eq(%i[blue])
      expect(partner.pending).to eq(%i[green])
    end

    it 'gifts when it grows nothing to ask for' do
      partner = player('Partner', %i[soy])
      game = BeanBazaar::Game.new(players: [player('Bot', []), partner], deck: deck, phase: :trade, face_up: BeanBazaar::Hand.new(%i[green]))
      described_class.new(game, 0).play_trade_phase(partner_indexes: [1])

      expect(partner.pending).to eq(%i[green])
      expect(partner.hand.cards).to eq(%i[soy])
    end

    it 'offers the poorest partner first' do
      bot = player('Bot', [], fields: [BeanBazaar::Field.new(bean: :soy, count: 2), BeanBazaar::Field.new(bean: :blue, count: 2)])
      rich = player('Rich', [], coin_cards: %i[red])
      poor = player('Poor', [])
      game = BeanBazaar::Game.new(players: [bot, rich, poor], deck: deck, phase: :trade, face_up: BeanBazaar::Hand.new(%i[green]))
      described_class.new(game, 0).play_trade_phase(partner_indexes: [1, 2])

      expect(poor.pending).to eq(%i[green])
      expect(rich.pending).to be_empty
    end

    it 'keeps a card nobody wants' do
      bot = player('Bot', [], fields: [BeanBazaar::Field.new(bean: :soy, count: 2), BeanBazaar::Field.new(bean: :blue, count: 2)])
      partner = player('Partner', [], fields: [BeanBazaar::Field.new(bean: :red, count: 1), BeanBazaar::Field.new(bean: :wax, count: 1)])
      game = BeanBazaar::Game.new(players: [bot, partner], deck: deck, phase: :trade, face_up: BeanBazaar::Hand.new(%i[green]))
      described_class.new(game, 0).play_trade_phase(partner_indexes: [1])

      expect(bot.pending).to eq(%i[green])
    end
  end

  describe '#plant_pending' do
    it 'plants every pending card' do
      bot = player('Bot', [])
      game = BeanBazaar::Game.new(players: [bot, player('Other', [])], deck: deck, phase: :plant_pending)
      bot.receive(%i[red red soy])
      described_class.new(game, 0).plant_pending

      expect(bot.fields.map(&:count)).to eq([2, 1])
      expect(bot.pending).to be_empty
    end
  end

  describe '#accepts?' do
    let(:game) do
      fields = [BeanBazaar::Field.new(bean: :soy, count: 2), BeanBazaar::Field.new]
      BeanBazaar::Game.new(players: [player('Bot', %i[soy red], fields: fields)], deck: deck)
    end
    let(:bot) { described_class.new(game, 0) }

    it 'takes cards it can plant' do
      expect(bot.accepts?(offered: %i[blue], requested: %i[red])).to be(true)
    end

    it 'refuses to give away a bean it grows' do
      expect(bot.accepts?(offered: %i[blue], requested: %i[soy])).to be(false)
    end

    it 'needs an empty field for each new bean type' do
      expect(bot.accepts?(offered: %i[blue red], requested: [])).to be(false)
      expect(bot.accepts?(offered: %i[blue soy], requested: [])).to be(true)
    end

    it 'never suggests a smaller deal' do
      expect(bot.counter_offer(offered: %i[blue red], requested: %i[soy])).to be_nil
    end

    it 'refuses cards it has no room for' do
      game.players.first.plant(:red, 1)

      expect(bot.accepts?(offered: %i[blue], requested: [])).to be(false)
    end
  end
end
