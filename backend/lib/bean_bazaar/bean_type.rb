module BeanBazaar
  # One kind of bean card. `meter` maps coins earned to beans needed, so
  # { 1 => 4, 2 => 6 } pays 1 coin for 4 beans and 2 coins for 6.
  BeanType = Data.define(:key, :name, :copies, :meter) do
    def self.all
      @all ||= [
        new(key: :blue, name: 'Blue', copies: 20, meter: { 1 => 4, 2 => 6, 3 => 8, 4 => 10 }),
        new(key: :chili, name: 'Chili', copies: 18, meter: { 1 => 3, 2 => 6, 3 => 8, 4 => 9 }),
        new(key: :stink, name: 'Stink', copies: 16, meter: { 1 => 3, 2 => 5, 3 => 7, 4 => 8 }),
        new(key: :green, name: 'Green', copies: 14, meter: { 1 => 3, 2 => 5, 3 => 6, 4 => 7 }),
        new(key: :soy, name: 'Soy', copies: 12, meter: { 1 => 2, 2 => 4, 3 => 6, 4 => 7 }),
        new(key: :black_eyed, name: 'Black-eyed', copies: 10, meter: { 1 => 2, 2 => 4, 3 => 5, 4 => 6 }),
        new(key: :red, name: 'Red', copies: 8, meter: { 1 => 2, 2 => 3, 3 => 4, 4 => 5 }),
        new(key: :wax, name: 'Wax', copies: 6, meter: { 2 => 2, 3 => 3 }),
      ].freeze
    end

    def self.find(key)
      all.find { |bean_type| bean_type.key == key } || raise(ArgumentError, "Unknown bean: #{key}")
    end

    # Every card in a fresh deck, one bean key per card.
    def self.full_deck
      all.flat_map { |bean_type| Array.new(bean_type.copies, bean_type.key) }
    end

    def coins_for(bean_count)
      meter.select { |_coins, beans_needed| bean_count >= beans_needed }.keys.max || 0
    end
  end
end
