require 'bean_bazaar'

# Each named Smart bot leans one way; a bot with another name plays it straight.
RSpec.describe BeanBazaar::Bots::Personality do
  def field(bean = nil, count = 0)
    BeanBazaar::Field.new(bean: bean, count: count)
  end

  def smart(name, hand, fields)
    bot = BeanBazaar::Player.new(name: name, hand: BeanBazaar::Hand.new(hand), fields: fields)
    game = BeanBazaar::Game.new(players: [BeanBazaar::Player.new(name: 'Asker'), bot], deck: BeanBazaar::Deck.new(draw_pile: []))
    BeanBazaar::Bots::SmartBot.new(game, 1)
  end

  it 'plays a bot with no personality straight' do
    expect(described_class.for('Bot')).to eq(described_class::PLAIN)
  end

  it 'makes Pinto take a lone gift a plain bot turns down' do
    expect(smart('Pinto', %i[soy], [field(:soy, 3), field]).accepts?(offered: %i[blue], requested: [])).to be(true)
    expect(smart('Bot', %i[soy], [field(:soy, 3), field]).accepts?(offered: %i[blue], requested: [])).to be(false)
  end

  it 'makes Lima charge a leader more' do
    leader = BeanBazaar::Player.new(name: 'Leader', coin_cards: %i[red])
    judge = lambda do |name|
      bot = BeanBazaar::Player.new(name: name, hand: BeanBazaar::Hand.new(%i[soy]), fields: [field(:soy, 3), field])
      game = BeanBazaar::Game.new(players: [leader, bot], deck: BeanBazaar::Deck.new(draw_pile: []))
      BeanBazaar::Bots::SmartBot.new(game, 1).accepts?(offered: %i[soy], requested: %i[wax wax])
    end

    expect(judge.call('Lima')).to be(false)
    expect(judge.call('Bot')).to be(true)
  end

  it 'makes Fava guard the bean of its biggest field' do
    fields = [field(:soy, 3), field(:blue, 1)]

    expect(smart('Fava', %i[soy], fields).accepts?(offered: %i[blue blue blue], requested: %i[soy])).to be(false)
    expect(smart('Bot', %i[soy], fields).accepts?(offered: %i[blue blue blue], requested: %i[soy])).to be(true)
  end

  it 'makes Mung dig up a field to chase a new bean' do
    fields = [field(:blue, 2), field(:green, 2)]

    expect(smart('Mung', [], fields).accepts?(offered: %i[red red], requested: [])).to be(true)
    expect(smart('Bot', [], fields).accepts?(offered: %i[red red], requested: [])).to be(false)
  end
end
