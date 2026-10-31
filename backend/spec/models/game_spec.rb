require "rails_helper"

RSpec.describe Game do
  let(:engine) { BeanBazaar::Game.start(names: %w[You Pinto Lima], random: Random.new(1)) }

  it "rebuilds the engine from its saved state" do
    game = described_class.create!(state: engine.to_h)

    expect(game.reload.engine.to_h).to eq(engine.to_h)
  end

  it "saves engine changes with #store" do
    game = described_class.create!(state: engine.to_h)
    engine.plant_from_hand(0)
    game.store(engine)

    expect(game.reload.engine.hand_plants).to eq(1)
  end

  it "needs a state and a valid human seat" do
    game = described_class.new(state: nil, human_index: -1)

    expect(game).not_to be_valid
    expect(game.errors.attribute_names).to contain_exactly(:state, :human_index)
  end
end
