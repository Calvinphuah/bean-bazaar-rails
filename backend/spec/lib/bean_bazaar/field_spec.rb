require "bean_bazaar"

RSpec.describe BeanBazaar::Field do
  subject(:field) { described_class.new }

  it "starts empty and earns nothing" do
    expect(field).to be_empty
    expect(field.coins).to eq(0)
  end

  describe "#plant" do
    it "takes any bean when empty, then only that bean" do
      field.plant(:soy)
      field.plant(:soy)

      expect(field.bean).to eq(:soy)
      expect(field.count).to eq(2)
      expect(field.accepts?(:red)).to be(false)
    end

    it "rejects a different bean" do
      field.plant(:soy)

      expect { field.plant(:red) }.to raise_error(BeanBazaar::IllegalMove, "This field already holds soy beans")
    end
  end

  describe "#harvest" do
    it "returns every card and empties the field" do
      4.times { field.plant(:blue) }

      expect(field.coins).to eq(1)
      expect(field.harvest).to eq(%i[blue blue blue blue])
      expect(field).to be_empty
      expect(field.accepts?(:red)).to be(true)
    end
  end
end
