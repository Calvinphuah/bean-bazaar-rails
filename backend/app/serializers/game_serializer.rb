# The game as the human sees it: their own hand in full, the bots' hands as
# counts only. Fields, coins, pending and face-up cards are public at the table.
class GameSerializer
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
      deck: { draw: @engine.deck.draw_pile.size, discard: @engine.deck.discard_pile.size, run_outs: @engine.deck.run_outs },
      face_up: @engine.face_up.cards,
      players: @engine.players.each_with_index.map { |player, index| player_json(player, index) },
      log: @engine.log,
      bean_types: BeanBazaar::BeanType.all.map(&:to_h)
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
      pending: player.pending
    }
  end

  def winner_indexes
    return [] if !@engine.over?

    @engine.winners.map { |winner| @engine.players.index(winner) }
  end
end
