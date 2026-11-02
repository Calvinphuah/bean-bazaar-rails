module BeanBazaar
  module Bots
    # How a named bot leans when it trades, on top of its level. Each knob nudges
    # one judgement, so the bots feel different without any of them playing badly.
    #   gift_kindness  how much less a gift must be worth before it takes it
    #   lead_wariness  how strongly it resists helping whoever is ahead
    #   deal_margin    how far ahead a swap must come out before it agrees
    #   uproot_scale   how much it minds digging up a field for a new bean
    #   hoards         whether it guards the bean of its biggest field
    Personality = Struct.new(:gift_kindness, :lead_wariness, :deal_margin, :uproot_scale, :hoards, keyword_init: true)

    class Personality
      # A bot whose name has no personality plays it straight.
      def self.for(name)
        ALL.fetch(name, PLAIN)
      end

      PLAIN = new(gift_kindness: 0, lead_wariness: 1.0, deal_margin: 1, uproot_scale: 1.0, hoards: false)
      ALL = {
        # Generous: happy to take and give gifts, shrugs at who is winning.
        'Pinto' => new(gift_kindness: 1, lead_wariness: 0.5, deal_margin: 1, uproot_scale: 1.0, hoards: false),
        # Shrewd: watches the leader closely and won't feed them.
        'Lima' => new(gift_kindness: 0, lead_wariness: 2.0, deal_margin: 1, uproot_scale: 1.0, hoards: false),
        # Collector: guards the bean of its biggest field above all else.
        'Fava' => new(gift_kindness: 0, lead_wariness: 1.0, deal_margin: 1, uproot_scale: 1.0, hoards: true),
        # Gambler: digs up fields lightly to chase a new bean.
        'Mung' => new(gift_kindness: 0, lead_wariness: 1.0, deal_margin: 1, uproot_scale: 0.5, hoards: false),
      }.freeze
    end
  end
end
