require 'bean_bazaar'

RSpec.describe BeanBazaar::Bots::SmartBot do
  def field(bean = nil, count = 0)
    BeanBazaar::Field.new(bean: bean, count: count)
  end

  def player(name, hand, fields: [field, field], coin_cards: [])
    BeanBazaar::Player.new(name: name, hand: BeanBazaar::Hand.new(hand), fields: fields, coin_cards: coin_cards)
  end

  let(:deck) { BeanBazaar::Deck.new(draw_pile: Array.new(30, :chili)) }

  def game_with(*players, **options)
    BeanBazaar::Game.new(players: players, deck: deck, **options)
  end

  describe '#play_plant_phase' do
    it 'keeps a field growing when the same bean is coming up in its hand' do
      bot = player('Bot', %i[wax soy soy], fields: [field(:soy, 3), field(:red, 2)])
      game = game_with(bot, player('Other', []))
      described_class.new(game, 0).play_plant_phase

      expect(bot.fields.map(&:bean)).to eq(%i[soy wax])
      expect(bot.coins).to eq(1)
    end

    it 'sells a field that has reached its top payout' do
      bot = player('Bot', %i[soy], fields: [field(:soy, 6), field(:wax, 3)])
      game = game_with(bot, player('Other', []))
      described_class.new(game, 0).play_plant_phase

      expect(bot.fields.last).to be_empty
      expect(bot.coins).to eq(4 + 3)
    end

    it 'leaves an empty field free for a different bean coming soon' do
      bot = player('Bot', %i[soy wax red], fields: [field, field])
      game = game_with(bot, player('Other', []))
      described_class.new(game, 0).play_plant_phase

      expect(bot.fields.map(&:bean)).to eq([:soy, nil])
    end

    it 'flips straight away with an empty hand' do
      game = game_with(player('Bot', []), player('Other', []))
      described_class.new(game, 0).play_plant_phase

      expect(game.phase).to eq(:trade)
    end

    it 'plants a second card that joins a field it grows' do
      bot = player('Bot', %i[soy soy], fields: [field, field])
      game = game_with(bot, player('Other', []))
      described_class.new(game, 0).play_plant_phase

      expect(bot.fields.first.count).to eq(2)
    end

    it 'buys a third field early but not in the last reshuffle' do
      rich = player('Bot', %i[soy], coin_cards: %i[red red red])
      described_class.new(game_with(rich, player('Other', [])), 0).play_plant_phase

      late = player('Late', %i[soy], coin_cards: %i[red red red])
      late_deck = BeanBazaar::Deck.new(draw_pile: Array.new(5, :chili), run_outs: 2)
      described_class.new(BeanBazaar::Game.new(players: [late, player('Other', [])], deck: late_deck), 0).play_plant_phase

      expect(rich.fields.size).to eq(3)
      expect(late.fields.size).to eq(2)
    end
  end

  describe '#play_trade_phase' do
    let(:bot) { player('Bot', %i[green], fields: [field(:soy, 2), field(:blue, 3)]) }
    let(:human) { player('You', %i[soy]) }

    it 'offers the human a card it cannot use for any bean it grows, the one it needs most first' do
      game = game_with(bot, human, phase: :trade, face_up: BeanBazaar::Hand.new(%i[red blue]))
      described_class.new(game, 0).play_trade_phase(partner_indexes: [], human_index: 1)

      # Blue at 3 is one bean from its next coin; soy at 2 is two away.
      expect(game.offer).to eq('partner_index' => 1, 'face_up_indexes' => [0], 'hand_indexes' => [], 'partner_beans' => [], 'choices' => %w[blue soy])
      expect(game.phase).to eq(:trade)
    end

    it 'skips a bean the human has said they hold none of' do
      game = game_with(bot, human, phase: :trade, face_up: BeanBazaar::Hand.new(%i[red blue]), lacking: [[], %i[blue]])
      described_class.new(game, 0).play_trade_phase(partner_indexes: [], human_index: 1)

      expect(game.offer['choices']).to eq(%w[soy])
    end

    it 'gives a hand card it has no field for to a bot that has more of it coming' do
      crowded = player('Bot', %i[soy red], fields: [field(:soy, 3), field(:wax, 2)])
      taker = player('Taker', %i[red])
      game = game_with(crowded, taker, phase: :trade)
      described_class.new(game, 0).play_trade_phase(partner_indexes: [1])

      expect(crowded.hand.cards).to eq(%i[soy])
      expect(taker.pending).to eq(%i[red])
    end

    it 'offers the human first, before sharing cards out to the bots' do
      taker = player('Taker', %i[red])
      game = game_with(bot, human, taker, phase: :trade, face_up: BeanBazaar::Hand.new(%i[red blue]))
      described_class.new(game, 0).play_trade_phase(partner_indexes: [2], human_index: 1)

      expect(game.offer).to include('partner_index' => 1, 'face_up_indexes' => [0])
      expect(taker.pending).to be_empty
    end

    it 'offers a loose hand card when every face-up card is useful' do
      game = game_with(bot, human, phase: :trade, face_up: BeanBazaar::Hand.new(%i[blue]))
      described_class.new(game, 0).play_trade_phase(partner_indexes: [], human_index: 1)

      expect(game.offer['hand_indexes']).to eq([0])
    end

    it 'makes at most two offers to the human per turn, then ends trading' do
      game = game_with(bot, human, phase: :trade, face_up: BeanBazaar::Hand.new(%i[red]), offers_this_turn: 2)
      described_class.new(game, 0).play_trade_phase(partner_indexes: [], human_index: 1)

      expect(game.offer).to be_nil
      expect(game.phase).to eq(:plant_pending)
    end

    it 'ends trading when it has nothing to offer' do
      useful = player('Bot', [], fields: [field(:soy, 2), field(:blue, 3)])
      game = game_with(useful, human, phase: :trade, face_up: BeanBazaar::Hand.new(%i[blue]))
      described_class.new(game, 0).play_trade_phase(partner_indexes: [], human_index: 1)

      expect(game.offer).to be_nil
    end

    it 'gifts the poorest player first, the human included, after a turned-down offer' do
      taker = player('Taker', %i[red])
      declined = [{ 'partner_index' => 1, 'gives' => %w[red], 'partner_beans' => [], 'choices' => %w[blue soy] },
                  { 'partner_index' => 1, 'gives' => %w[red], 'partner_beans' => [], 'choices' => [] }]
      game = game_with(bot, human, taker, phase: :trade, face_up: BeanBazaar::Hand.new(%i[red wax]), declined: declined)
      described_class.new(game, 0).play_trade_phase(partner_indexes: [2], human_index: 1)

      # The human turned the red bean down, so the taker gets it and the human is offered the wax.
      expect(taker.pending).to eq(%i[red])
      expect(game.offer).to include('partner_index' => 1, 'face_up_indexes' => [0], 'choices' => [])
      expect(game.face_up.cards).to eq(%i[wax])
    end

    it 'gives to a poorer bot before a richer human' do
      rich = player('You', %i[soy], coin_cards: %i[red])
      taker = player('Taker', %i[red])
      game = game_with(bot, rich, taker, phase: :trade, face_up: BeanBazaar::Hand.new(%i[red]), offers_this_turn: 2)
      described_class.new(game, 0).play_trade_phase(partner_indexes: [2], human_index: 1)

      expect(taker.pending).to eq(%i[red])
      expect(game.offer).to be_nil
    end

    it 'keeps a flipped card it can start a free field with' do
      fresh = player('Bot', %i[wax])
      game = game_with(fresh, human, phase: :trade, face_up: BeanBazaar::Hand.new(%i[blue]))
      described_class.new(game, 0).play_trade_phase(partner_indexes: [], human_index: 1)

      expect(game.offer).to be_nil
      expect(fresh.pending).to eq(%i[blue])
    end

    it 'gifts a flipped card when the human lacks every bean it grows' do
      game = game_with(bot, human, phase: :trade, face_up: BeanBazaar::Hand.new(%i[red]), lacking: [[], %i[soy blue]])
      described_class.new(game, 0).play_trade_phase(partner_indexes: [], human_index: 1)

      expect(game.offer).to include('face_up_indexes' => [0], 'choices' => [])
    end
  end

  describe '#accepts?' do
    let(:bot) { player('Bot', %i[soy wax], fields: [field(:soy, 3), field]) }
    let(:smart) { described_class.new(game_with(bot, player('Other', [])), 0) }

    it 'takes a bean that reaches its next coin' do
      expect(smart.accepts?(offered: %i[soy], requested: %i[wax])).to be(true)
    end

    it 'gives up a loose card for a free one' do
      bot.plant(:red, 1)

      expect(smart.accepts?(offered: %i[soy], requested: %i[wax])).to be(true)
    end

    it 'refuses to hand over a bean it grows for one it cannot use' do
      bot.plant(:red, 1)

      expect(smart.accepts?(offered: %i[blue], requested: %i[soy])).to be(false)
    end

    it 'keeps its empty field for the card it must plant next' do
      wax_first = player('Bot', %i[wax soy], fields: [field(:soy, 3), field])

      expect(described_class.new(game_with(wax_first, player('Other', [])), 0).accepts?(offered: %i[blue], requested: [])).to be(false)
    end

    it 'turns down a lone junk bean even with a field free' do
      fresh = player('Bot', %i[soy], fields: [field(:soy, 3), field])

      expect(described_class.new(game_with(fresh, player('Other', [])), 0).accepts?(offered: %i[blue], requested: [])).to be(false)
    end

    it 'takes a gift for a free field when more of that bean is coming in its hand' do
      fresh = player('Bot', %i[soy blue], fields: [field(:soy, 3), field])

      expect(described_class.new(game_with(fresh, player('Other', [])), 0).accepts?(offered: %i[blue], requested: [])).to be(true)
    end

    it 'asks more of a leader before helping them' do
      bot = player('Bot', %i[soy wax], fields: [field(:soy, 3), field])
      level = described_class.new(game_with(player('Asker', []), bot), 1)
      leader = described_class.new(game_with(player('Asker', [], coin_cards: %i[red red red]), bot), 1)

      expect(level.accepts?(offered: %i[soy], requested: %i[soy])).to be(true)
      expect(leader.accepts?(offered: %i[soy], requested: %i[soy])).to be(false)
    end

    it 'turns down a pile of different beans it would have to dig up fields for' do
      fresh = player('Bot', %i[soy], fields: [field(:soy, 3), field])

      expect(described_class.new(game_with(fresh, player('Other', [])), 0).accepts?(offered: %i[blue red wax], requested: [])).to be(false)
    end

    it 'never takes more new bean types than it has fields to put them in' do
      rich = player('Bot', %i[soy], fields: [field(:soy, 3), field(:red, 2)])
      generous = %i[blue blue blue blue wax chili]

      expect(described_class.new(game_with(rich, player('Other', [])), 0).accepts?(offered: generous, requested: [])).to be(false)
    end

    it 'wants something back for a card the asker needs' do
      expect(smart.accepts?(offered: [], requested: %i[wax])).to be(false)
    end
  end

  describe '#counter_offer' do
    let(:bot) { player('Bot', %i[soy wax], fields: [field(:soy, 3), field]) }
    let(:smart) { described_class.new(game_with(bot, player('Other', [])), 0) }

    it 'keeps the bean it grows out of the deal and still trades the rest' do
      expect(smart.accepts?(offered: %i[soy], requested: %i[wax soy])).to be(false)
      expect(smart.counter_offer(offered: %i[soy], requested: %i[wax soy])).to eq(offered: %i[soy], requested: %i[wax])
    end

    it 'never counters with just "give me your card" when the asker wanted beans' do
      leader = described_class.new(game_with(player('Asker', [], coin_cards: %i[red red red]), bot), 1)

      expect(leader.counter_offer(offered: %i[soy], requested: %i[soy])).to be_nil
    end

    it 'has no counter when no smaller deal is any good' do
      expect(smart.counter_offer(offered: [], requested: %i[soy])).to be_nil
    end
  end

  describe '#plant_pending' do
    it 'plants the fitting cards first, then makes room for the rest' do
      bot = player('Bot', [], fields: [field(:soy, 2), field(:red, 2)])
      game = game_with(bot, player('Other', []), phase: :plant_pending)
      bot.receive(%i[wax soy])
      described_class.new(game, 0).plant_pending

      expect(bot.fields.map(&:bean)).to eq(%i[soy wax])
      expect(bot.pending).to be_empty
    end
  end

  # Against two easy bots a fair share is one game in three; it should win clearly more.
  it 'beats the easy bots over many games' do
    games = 100
    wins = games.times.count do |seed|
      game = BeanBazaar::Game.start(names: %w[Smart Easy1 Easy2], random: Random.new(seed))
      runner = BeanBazaar::BotRunner.new(game, human_index: nil)
      smart = described_class
      # Seat 0 plays smart, the others play easy.
      allow(runner).to receive(:bot) { |index| (index.zero? ? smart : BeanBazaar::Bots::SimpleBot).new(game, index) }
      runner.run
      game.winners.include?(game.players.first)
    end

    expect(wins).to be >= games * 0.4
  end
end
