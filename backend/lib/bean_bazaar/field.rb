module BeanBazaar
  # A bean field holds any number of beans, all of one type.
  class Field
    attr_reader :bean, :count

    def self.from_h(hash)
      new(bean: hash["bean"]&.to_sym, count: hash["count"])
    end

    def initialize(bean: nil, count: 0)
      @bean = bean
      @count = count
    end

    def to_h
      { bean: bean, count: count }
    end

    def empty?
      count.zero?
    end

    def accepts?(card)
      empty? || bean == card
    end

    def plant(card)
      raise IllegalMove, "This field already holds #{bean} beans" if !accepts?(card)

      @bean = card
      @count += 1
    end

    def coins
      return 0 if empty?

      BeanType.find(bean).coins_for(count)
    end

    # Empties the field and returns every card that was in it.
    def harvest
      cards = Array.new(count, bean)
      @bean = nil
      @count = 0
      cards
    end
  end
end
