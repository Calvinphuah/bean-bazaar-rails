require 'bean_bazaar'

RSpec.describe BeanBazaar::BotRunner do
  def card_total(game)
    game.deck.draw_pile.size + game.deck.discard_pile.size + game.face_up.size +
      game.players.sum { |player| player.hand.size + player.pending.size + player.coins + player.fields.sum(&:count) }
  end

  [3, 4, 5].each do |player_count|
    it "plays a full #{player_count}-bot game to the end without losing a card" do
      5.times do |seed|
        game = BeanBazaar::Game.start(names: Array.new(player_count) { |index| "Bot #{index}" }, random: Random.new(seed))
        described_class.new(game, human_index: nil).run

        expect(game).to be_over
        expect(card_total(game)).to eq(BeanBazaar::BeanType.full_deck(player_count).size)
        expect(game.winners).not_to be_empty
      end
    end
  end

  it "stops when it is the human's turn" do
    game = BeanBazaar::Game.start(names: %w[You Bot1 Bot2], random: Random.new(1))
    described_class.new(game, human_index: 0).run

    expect(game.active_index).to eq(0)
    expect(game.phase).to eq(:plant)
  end

  it "plays the bots' turns and hands back to the human" do
    game = BeanBazaar::Game.start(names: %w[You Bot1 Bot2], random: Random.new(1))
    game.plant_from_hand(0)
    game.flip_cards
    game.end_trading
    runner = described_class.new(game, human_index: 0)
    runner.run
    # Plant the human's cards the way a bot would, then let the bots finish the round.
    runner.bot(0).plant_pending
    runner.run

    expect(game.active_index).to eq(0)
    expect(card_total(game)).to eq(BeanBazaar::BeanType.full_deck(3).size)
  end

  it 'waits while the human still has pending cards to plant' do
    game = BeanBazaar::Game.start(names: %w[You Bot1 Bot2], random: Random.new(2))
    game.plant_from_hand(0)
    game.flip_cards
    game.end_trading
    described_class.new(game, human_index: 0).run

    expect(game.phase).to eq(:plant_pending)
    expect(game.players.first.pending).not_to be_empty
    expect(game.players.drop(1).map(&:pending)).to all(be_empty)
  end

  it "pauses while a smart bot's offer waits for the human" do
    bot = BeanBazaar::Player.new(
      name: 'Bot',
      fields: [BeanBazaar::Field.new(bean: :soy, count: 2), BeanBazaar::Field.new(bean: :blue, count: 2)],
    )
    human = BeanBazaar::Player.new(name: 'You', hand: BeanBazaar::Hand.new(%i[soy]))
    # Full fields of other beans, so this bot turns the red bean down and it goes to the human.
    other = BeanBazaar::Player.new(
      name: 'Other',
      fields: [BeanBazaar::Field.new(bean: :wax, count: 2), BeanBazaar::Field.new(bean: :green, count: 2)],
    )
    deck = BeanBazaar::Deck.new(draw_pile: Array.new(30, :chili))
    game = BeanBazaar::Game.new(players: [bot, human, other], deck: deck, phase: :trade, face_up: BeanBazaar::Hand.new(%i[red]))
    described_class.new(game, human_index: 1, bot_class: BeanBazaar::Bots::SmartBot).run

    expect(game.offer).to include('partner_index' => 1, 'choices' => %w[soy blue])
    expect(game.phase).to eq(:trade)

    # Turned down, the swap comes back once as a gift, never as the same offer.
    game.decline_offer
    described_class.new(game, human_index: 1, bot_class: BeanBazaar::Bots::SmartBot).run

    expect(game.offer).to include('partner_index' => 1, 'choices' => [])

    game.decline_offer
    described_class.new(game, human_index: 1, bot_class: BeanBazaar::Bots::SmartBot).run

    expect(game.offer).to be_nil
    expect(game.active_index).to eq(1)
  end

  it 'raises if the bots stop making progress' do
    stuck_bot = Class.new do
      def initialize(*)
        nil
      end
      def play_plant_phase
        nil
      end
      def plant_pending
        nil
      end
    end
    game = BeanBazaar::Game.start(names: %w[A B C], random: Random.new(1))
    runner = described_class.new(game, human_index: nil, bot_class: stuck_bot)
    stub_const('BeanBazaar::BotRunner::MAX_STEPS', 3)

    expect { runner.run }.to raise_error(RuntimeError, 'Bots made no progress after 3 steps')
  end
end
