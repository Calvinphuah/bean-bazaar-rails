require 'bean_bazaar'

RSpec.describe BeanBazaar::Player do
  subject(:player) { described_class.new(name: 'Calvin') }

  def field_with(bean, count)
    BeanBazaar::Field.new(bean: bean, count: count)
  end

  it 'starts with two empty fields and no coins' do
    expect(player.fields.size).to eq(2)
    expect(player.coins).to eq(0)
  end

  it "rejects a field that doesn't exist" do
    expect { player.plant(:soy, 2) }.to raise_error(BeanBazaar::IllegalMove, 'There is no field 2')
  end

  describe '#harvest' do
    it 'keeps coin cards and returns the rest for the discard pile' do
      player = described_class.new(name: 'Calvin', fields: [field_with(:blue, 6), field_with(:soy, 1)])

      expect(player.harvest(0)).to eq(%i[blue blue blue blue])
      expect(player.coins).to eq(2)
      expect(player.fields.first).to be_empty
    end

    it 'rejects an empty field' do
      expect { player.harvest(0) }.to raise_error(BeanBazaar::IllegalMove, 'That field is empty')
    end

    it 'protects a lone bean while another field has more than one' do
      player = described_class.new(name: 'Calvin', fields: [field_with(:soy, 1), field_with(:red, 2)])

      expect { player.harvest(0) }.to raise_error(BeanBazaar::IllegalMove, 'Harvest a field with more beans first')
    end

    it 'allows a lone bean when every field has at most one' do
      player = described_class.new(name: 'Calvin', fields: [field_with(:soy, 1), field_with(:red, 1)])

      expect(player.harvest(0)).to eq(%i[soy])
    end
  end

  describe '#harvest_all' do
    it 'harvests every field, ignoring the lone-bean rule' do
      player = described_class.new(name: 'Calvin', fields: [field_with(:soy, 1), field_with(:red, 3)])

      expect(player.harvest_all).to eq(%i[soy red])
      expect(player.coins).to eq(2)
      expect(player.fields).to all(be_empty)
    end
  end

  describe '#plant_pending' do
    it 'plants a pending card and removes it from pending' do
      player.receive(%i[red soy])
      player.plant_pending(1, 0)

      expect(player.pending).to eq(%i[red])
      expect(player.fields.first.bean).to eq(:soy)
    end

    it 'rejects a pending position with no card' do
      expect { player.plant_pending(0, 0) }.to raise_error(BeanBazaar::IllegalMove, 'There is no card at position 0')
    end
  end

  describe '#buy_third_field' do
    it 'spends 3 coins for a third field' do
      player = described_class.new(name: 'Calvin', coin_cards: %i[blue soy red wax])

      expect(player.buy_third_field).to eq(%i[soy red wax])
      expect(player.fields.size).to eq(3)
      expect(player.coins).to eq(1)
    end

    it 'needs 3 coins' do
      player = described_class.new(name: 'Calvin', coin_cards: %i[blue soy])

      expect { player.buy_third_field }.to raise_error(BeanBazaar::IllegalMove, 'A third field costs 3 coins')
    end

    it 'allows only one extra field' do
      player = described_class.new(name: 'Calvin', coin_cards: Array.new(6, :blue))
      player.buy_third_field

      expect { player.buy_third_field }.to raise_error(BeanBazaar::IllegalMove, 'You already have 3 fields')
    end
  end
end
