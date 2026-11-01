# Game rules for Bean Bazaar. Plain Ruby with no Rails, so the same engine runs
# in specs, the console, the API and a future Action Cable channel.
require_relative 'bean_bazaar/illegal_move'
require_relative 'bean_bazaar/bean_type'
require_relative 'bean_bazaar/deck'
require_relative 'bean_bazaar/hand'
require_relative 'bean_bazaar/field'
require_relative 'bean_bazaar/player'
require_relative 'bean_bazaar/trade'
require_relative 'bean_bazaar/game'
require_relative 'bean_bazaar/bots/personality'
require_relative 'bean_bazaar/bots/simple_bot'
require_relative 'bean_bazaar/bots/smart_bot'
require_relative 'bean_bazaar/bots/normal_bot'
require_relative 'bean_bazaar/bot_runner'

module BeanBazaar
end
