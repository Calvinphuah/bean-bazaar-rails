require 'rails_helper'

RSpec.describe Games::Create do
  it 'seats the human first against the chosen bots and waits for their move' do
    result = described_class.new(3, random: Random.new(1)).call
    engine = result[:payload].engine

    expect(result).to include(success: true, root_name: :game)
    expect(result[:extra_params][:success_message]).to eq('Cards dealt. Good luck!')
    expect(engine.players.map(&:name)).to eq(%w[You Pinto Lima Fava])
    expect(result[:payload].human_index).to eq(0)
    expect(engine.active_index).to eq(0)
    expect(engine.phase).to eq(:plant)
  end

  it 'accepts the bot count as a string from params' do
    expect(described_class.new('2').call[:payload].engine.players.size).to eq(3)
  end

  it 'rejects a bot count outside 2 to 4 without saving' do
    result = described_class.new(5).call

    expect(result).to include(success: false, payload: nil)
    expect(result[:extra_params][:alert]).to eq('Choose 2 to 4 bots')
    expect(Game.count).to eq(0)
  end

  it 'rejects a bot count that is not a number' do
    expect(described_class.new('lots').call[:extra_params][:alert]).to eq('Choose 2 to 4 bots')
  end

  it 'plays easy or smart bots' do
    expect(described_class.new(2, 'easy').call[:payload].bot_level).to eq('easy')
    expect(described_class.new(2).call[:payload].bot_level).to eq('smart')
  end

  it 'rejects an unknown bot level' do
    result = described_class.new(2, 'genius').call

    expect(result).to include(success: false)
    expect(result[:extra_params][:alert]).to eq('Choose easy or smart bots')
  end

  it 'rolls back and reports a save failure' do
    allow_any_instance_of(Game).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(Game.new)) # rubocop:disable RSpec/AnyInstance
    result = described_class.new(2).call

    expect(result[:success]).to be(false)
    expect(result[:extra_params][:alert]).to eq("The game couldn't be dealt, please try again")
  end
end
