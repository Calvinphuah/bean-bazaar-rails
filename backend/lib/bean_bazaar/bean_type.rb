module BeanBazaar
  # One kind of bean card. `meter` maps coins earned to beans needed, so
  # { 1 => 4, 2 => 6 } pays 1 coin for 4 beans and 2 coins for 6.
  # `min_players` keeps a bean out of smaller games, which run long enough without it.
  BeanType = Data.define(:key, :name, :copies, :meter, :min_players) do
    def initialize(key:, name:, copies:, meter:, min_players: 3)
      super
    end

    def self.all
      @all ||= [
        # Coffee and Golden only join a 5-player game, making its deck 130 cards.
        new(key: :coffee, name: 'Coffee', copies: 22, meter: { 1 => 4, 2 => 7, 3 => 9, 4 => 11 }, min_players: 5),
        new(key: :blue, name: 'Blue', copies: 20, meter: { 1 => 4, 2 => 6, 3 => 8, 4 => 10 }),
        new(key: :chili, name: 'Chili', copies: 18, meter: { 1 => 3, 2 => 6, 3 => 8, 4 => 9 }),
        new(key: :stink, name: 'Stink', copies: 16, meter: { 1 => 3, 2 => 5, 3 => 7, 4 => 8 }),
        new(key: :green, name: 'Green', copies: 14, meter: { 1 => 3, 2 => 5, 3 => 6, 4 => 7 }),
        new(key: :soy, name: 'Soy', copies: 12, meter: { 1 => 2, 2 => 4, 3 => 6, 4 => 7 }),
        new(key: :black_eyed, name: 'Black-eyed', copies: 10, meter: { 1 => 2, 2 => 4, 3 => 5, 4 => 6 }),
        new(key: :red, name: 'Red', copies: 8, meter: { 1 => 2, 2 => 3, 3 => 4, 4 => 5 }),
        new(key: :wax, name: 'Wax', copies: 6, meter: { 2 => 2, 3 => 3 }),
        # Rare: only 4 cards, and it never pays a single coin.
        new(key: :golden, name: 'Golden', copies: 4, meter: { 2 => 2, 3 => 3, 4 => 4 }, min_players: 5),
      ].freeze
    end

    def self.find(key)
      all.find { |bean_type| bean_type.key == key } || raise(ArgumentError, "Unknown bean: #{key}")
    end

    # The beans in a game for this many players.
    def self.for_players(player_count)
      all.select { |bean_type| bean_type.min_players <= player_count }
    end

    # Every card in a fresh deck for this many players, one bean key per card.
    def self.full_deck(player_count)
      for_players(player_count).flat_map { |bean_type| Array.new(bean_type.copies, bean_type.key) }
    end

    # Beans needed for the next coin step above `bean_count`; nil once fully paid.
    def next_step(bean_count)
      meter.values.select { |beans_needed| beans_needed > bean_count }.min
    end

    def coins_for(bean_count)
      meter.select { |_coins, beans_needed| bean_count >= beans_needed }.keys.max || 0
    end
  end
end
