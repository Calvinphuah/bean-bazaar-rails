class Api::MovesController < Api::BaseController
  before_action :set_game

  # POST: /api/games/:game_id/moves
  # @overload create(game_id)
  #   @param game_id [String] game_id to play the move in
  #   @param move_params [ActionController::Parameters] the human's move
  #   @return [JSON] object: { game } or { game: { error_message } }
  # @raise [NotFound] Raise Not Found if Game not found based on param game_id
  def create
    result = Games::MakeMove.new(@game, move_params).call
    render_result(result)
  end

  private

  # Set game
  def set_game
    @game = Game.find(params[:game_id])
  end

  def move_params
    params.expect(
      move: [:type, :field_index, :pending_index, :partner_index, :bean, face_up_indexes: [], hand_indexes: [], partner_beans: []],
    )
  end
end
