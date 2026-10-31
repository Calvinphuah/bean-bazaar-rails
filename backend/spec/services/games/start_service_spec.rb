require "rails_helper"

RSpec.describe Games::StartService do
  it "seats the human first against the chosen bots and waits for their move" do
    game = described_class.new(bot_count: 3, random: Random.new(1)).call
    engine = game.engine

    expect(engine.players.map(&:name)).to eq(%w[You Pinto Lima Fava])
    expect(game.human_index).to eq(0)
    expect(engine.active_index).to eq(0)
    expect(engine.phase).to eq(:plant)
  end

  it "rejects a bot count outside 2 to 4" do
    expect { described_class.new(bot_count: 1).call }.to raise_error(BeanBazaar::IllegalMove, "Choose 2 to 4 bots")
    expect { described_class.new(bot_count: 5).call }.to raise_error(BeanBazaar::IllegalMove)
  end
end
