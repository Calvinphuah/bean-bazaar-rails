require 'bean_bazaar'

RSpec.describe BeanBazaar::Deck do
  describe '.shuffled' do
    it 'holds the full deck in a repeatable order for a seed' do
      deck = described_class.shuffled(player_count: 3, random: Random.new(1))
      same_seed = described_class.shuffled(player_count: 3, random: Random.new(1))

      expect(deck.draw_pile.tally).to eq(BeanBazaar::BeanType.full_deck(3).tally)
      expect(deck.draw_pile).to eq(same_seed.draw_pile)
    end
  end

  describe '#draw' do
    it 'takes cards from the top' do
      deck = described_class.new(draw_pile: %i[blue soy red])

      expect(deck.draw(2)).to eq(%i[blue soy])
      expect(deck.draw_pile).to eq(%i[red])
    end

    it 'shuffles the discards back in when the pile runs dry' do
      deck = described_class.new(draw_pile: %i[blue], discard_pile: %i[soy])

      expect(deck.draw(2)).to eq(%i[blue soy])
      expect(deck.run_outs).to eq(1)
      expect(deck.discard_pile).to be_empty
    end

    it 'stops on the third run-out' do
      deck = described_class.new(draw_pile: %i[blue], discard_pile: %i[soy], run_outs: 2)

      expect(deck.draw(3)).to eq(%i[blue])
      expect(deck).to be_exhausted
      expect(deck.draw(1)).to be_empty
    end
  end

  describe '#summary' do
    it 'shows the pile sizes and only the top of the discard pile' do
      deck = described_class.new(draw_pile: %i[blue], discard_pile: %i[soy red wax chili], run_outs: 1)

      expect(deck.summary).to eq(draw: 1, discard: 4, discard_top: %i[red wax chili], run_outs: 1)
    end
  end

  describe '#discard' do
    it 'adds cards to the discard pile' do
      deck = described_class.new(draw_pile: [])
      deck.discard(%i[red red])

      expect(deck.discard_pile).to eq(%i[red red])
    end
  end
end
