class Api::GamesController < Api::BaseController
  before_action :set_game, only: %i[show]

  # POST: /api/games
  # @overload create
  #   @param bot_count [Integer] how many bots to play against, default 3
  #   @param bot_level [String] "easy", "normal" or "smart", default normal
  #   @return [JSON] object: { game }
  def create
    result = Games::Create.new(
      params.fetch(:bot_count, Games::DEFAULT_BOT_COUNT),
      params.fetch(:bot_level, Games::DEFAULT_BOT_LEVEL),
    ).call
    render_result(result, success_code: :created)
  end

  # GET: /api/games/:id
  # @overload show(game_id)
  #   @param game_id [String] game_id to query
  #   @return [JSON] object: { game }
  # @raise [NotFound] Raise Not Found if Game not found based on param game_id
  def show
    render json: { game: serialize(@game) }
  end

  private

  # Set game
  def set_game
    @game = Game.find(params[:id])
  end
end
