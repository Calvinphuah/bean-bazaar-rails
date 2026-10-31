require "bean_bazaar"

RSpec.describe BeanBazaar::BeanType do
  describe ".all" do
    it "has the 8 base beans totalling 104 cards" do
      expect(described_class.all.map(&:key)).to eq(%i[blue chili stink green soy black_eyed red wax])
      expect(described_class.all.sum(&:copies)).to eq(104)
    end
  end

  describe ".find" do
    it "returns the bean type for a key" do
      expect(described_class.find(:soy).name).to eq("Soy")
    end

    it "raises for an unknown key" do
      expect { described_class.find(:coffee) }.to raise_error(ArgumentError, "Unknown bean: coffee")
    end
  end

  describe ".full_deck" do
    it "has one card per copy" do
      deck = described_class.full_deck

      expect(deck.size).to eq(104)
      expect(deck.count(:blue)).to eq(20)
      expect(deck.count(:wax)).to eq(6)
    end
  end

  describe "#coins_for" do
    let(:blue) { described_class.find(:blue) }

    it "pays nothing below the first step" do
      expect(blue.coins_for(3)).to eq(0)
    end

    it "pays the highest step reached" do
      expect(blue.coins_for(4)).to eq(1)
      expect(blue.coins_for(7)).to eq(2)
      expect(blue.coins_for(15)).to eq(4)
    end

    it "skips missing steps for rare beans" do
      wax = described_class.find(:wax)

      expect(wax.coins_for(1)).to eq(0)
      expect(wax.coins_for(2)).to eq(2)
      expect(wax.coins_for(6)).to eq(3)
    end
  end
end
