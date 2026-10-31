require "bean_bazaar"

RSpec.describe BeanBazaar::Trade do
  let(:active) { BeanBazaar::Player.new(name: "Calvin", hand: BeanBazaar::Hand.new(%i[blue soy])) }
  let(:partner) { BeanBazaar::Player.new(name: "Bot", hand: BeanBazaar::Hand.new(%i[red wax])) }
  let(:face_up) { BeanBazaar::Hand.new(%i[chili green]) }

  def trade(**indexes)
    described_class.new(active: active, partner: partner, face_up: face_up, **indexes)
  end

  it "swaps face-up and hand cards into each other's pending cards" do
    trade(face_up_indexes: [ 1 ], hand_indexes: [ 0 ], partner_hand_indexes: [ 1 ]).execute

    expect(partner.pending).to eq(%i[green blue])
    expect(active.pending).to eq(%i[wax])
    expect(face_up.cards).to eq(%i[chili])
    expect(active.hand.cards).to eq(%i[soy])
    expect(partner.hand.cards).to eq(%i[red])
  end

  it "allows a gift" do
    trade(face_up_indexes: [ 0 ]).execute

    expect(partner.pending).to eq(%i[chili])
    expect(active.pending).to be_empty
  end

  it "rejects an empty trade" do
    expect { trade.execute }.to raise_error(BeanBazaar::IllegalMove, "A trade needs at least one card")
  end

  it "rejects trading with yourself" do
    self_trade = described_class.new(active: active, partner: active, face_up: face_up, hand_indexes: [ 0 ])

    expect { self_trade.execute }.to raise_error(BeanBazaar::IllegalMove, "You can't trade with yourself")
  end

  it "changes nothing when one side is invalid" do
    expect { trade(hand_indexes: [ 0 ], partner_hand_indexes: [ 5 ]).execute }.to raise_error(BeanBazaar::IllegalMove)

    expect(active.hand.cards).to eq(%i[blue soy])
    expect(partner.pending).to be_empty
  end
end
