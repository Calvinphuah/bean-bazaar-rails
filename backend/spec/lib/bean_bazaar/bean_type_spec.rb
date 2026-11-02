require 'bean_bazaar'

RSpec.describe BeanBazaar::BeanType do
  describe '.all' do
    it 'has 10 beans totalling 130 cards' do
      expect(described_class.all.map(&:key)).to eq(%i[coffee blue chili stink green soy black_eyed red wax golden])
      expect(described_class.all.sum(&:copies)).to eq(130)
    end
  end

  describe '.find' do
    it 'returns the bean type for a key' do
      expect(described_class.find(:soy).name).to eq('Soy')
    end

    it 'raises for an unknown key' do
      expect { described_class.find(:cocoa) }.to raise_error(ArgumentError, 'Unknown bean: cocoa')
    end
  end

  describe '.full_deck' do
    it 'has one card per copy, adding Coffee and Golden only for 5 players' do
      small = described_class.full_deck(4)
      big = described_class.full_deck(5)

      expect(small.size).to eq(104)
      expect(small).not_to include(:coffee, :golden)
      expect(big.size).to eq(130)
      expect(big.count(:coffee)).to eq(22)
      expect(big.count(:golden)).to eq(4)
    end
  end

  describe '#coins_for' do
    let(:blue) { described_class.find(:blue) }

    it 'pays nothing below the first step' do
      expect(blue.coins_for(3)).to eq(0)
    end

    it 'pays the highest step reached' do
      expect(blue.coins_for(4)).to eq(1)
      expect(blue.coins_for(7)).to eq(2)
      expect(blue.coins_for(15)).to eq(4)
    end

    it 'skips missing steps for rare beans' do
      wax = described_class.find(:wax)

      expect(wax.coins_for(1)).to eq(0)
      expect(wax.coins_for(2)).to eq(2)
      expect(wax.coins_for(6)).to eq(3)
    end

    it 'never pays a single coin for the golden bean' do
      golden = described_class.find(:golden)

      expect([1, 2, 3, 4].map { |count| golden.coins_for(count) }).to eq([0, 2, 3, 4])
    end
  end
end
