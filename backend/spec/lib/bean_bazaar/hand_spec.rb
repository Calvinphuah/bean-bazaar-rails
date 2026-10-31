require "bean_bazaar"

RSpec.describe BeanBazaar::Hand do
  subject(:hand) { described_class.new(%i[blue soy red]) }

  it "adds new cards to the back" do
    hand.add(%i[wax])

    expect(hand.cards).to eq(%i[blue soy red wax])
  end

  it "plants from the front" do
    expect(hand.front).to eq(:blue)
    expect(hand.take_front).to eq(:blue)
    expect(hand.cards).to eq(%i[soy red])
  end

  it "takes every card" do
    expect(hand.take_all).to eq(%i[blue soy red])
    expect(hand).to be_empty
  end

  describe "#take_at" do
    it "removes the picked cards and keeps the rest in order" do
      expect(hand.take_at([ 2, 0 ])).to eq(%i[blue red])
      expect(hand.cards).to eq(%i[soy])
      expect(hand.size).to eq(1)
    end

    it "rejects a card picked twice" do
      expect { hand.take_at([ 1, 1 ]) }.to raise_error(BeanBazaar::IllegalMove, "Pick each card only once")
    end

    it "rejects a position with no card" do
      expect { hand.take_at([ 3 ]) }.to raise_error(BeanBazaar::IllegalMove, "There is no card at position 3")
      expect(hand.cards).to eq(%i[blue soy red])
    end
  end
end
