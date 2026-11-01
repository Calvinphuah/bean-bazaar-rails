# The game as the human sees it: their own hand in full, the bots' hands as
# counts only. Fields, coins, pending and face-up cards are public at the table.
class Api::GameSerializer
  def initialize(game)
    @game = game
    @engine = game.engine
  end

  def as_json(*)
    {
      id: @game.id,
      you: @game.human_index,
      phase: @engine.phase,
      active_index: @engine.active_index,
      hand_plants: @engine.hand_plants,
      over: @engine.over?,
      winners: winner_indexes,
      deck: @engine.deck.summary,
      face_up: @engine.face_up.cards,
      players: @engine.players.each_with_index.map { |player, index| player_json(player, index) },
      offer: offer_json,
      # You turned a bot's offer down to make your own; it waits for you.
      bidding: @engine.bidding == @game.human_index,
      bot_level: @game.bot_level,
      can_undo: @game.undo_states.any?,
      log: @engine.log,
      bean_types: BeanBazaar::BeanType.for_players(@engine.players.size).map(&:to_h),
    }
  end

  private

  def player_json(player, index)
    {
      name: player.name,
      hand: index == @game.human_index ? player.hand.cards : nil,
      hand_size: player.hand.size,
      fields: player.fields.map { |field| field.to_h.merge(coins: field.coins) },
      coins: player.coins,
      pending: player.pending,
    }
  end

  # A bot's offer waiting for the human, with the cards spelled out. choices are
  # beans the bot would take instead of ask, any one of them.
  def offer_json
    offer = @engine.offer
    return nil if offer.nil? || offer['partner_index'] != @game.human_index

    gives = offer['face_up_indexes'].map { |index| @engine.face_up.cards[index] } +
            offer['hand_indexes'].map { |index| @engine.active_player.hand.cards[index] }
    { from: @engine.active_index, give: gives, ask: offer['partner_beans'], choices: offer.fetch('choices', []) }
  end

  def winner_indexes
    return [] if !@engine.over?

    @engine.winners.map { |winner| @engine.players.index(winner) }
  end
end
