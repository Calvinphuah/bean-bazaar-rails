class Api::TradeQuotesController < Api::BaseController
  before_action :set_game

  # POST: /api/games/:game_id/trade_quotes
  # @overload create(game_id)
  #   @param game_id [String] game_id to quote the trade in
  #   @param quote_params [ActionController::Parameters] the cards offered and beans asked for
  #   @return [JSON] object: { quote: { answers } } or { quote: { error_message } }
  # @raise [NotFound] Raise Not Found if Game not found based on param game_id
  def create
    result = Games::QuoteTrade.new(@game, quote_params).call
    render_result(result)
  end

  private

  # Set game
  def set_game
    @game = Game.find(params[:game_id])
  end

  def quote_params
    params.fetch(:quote, {}).permit(face_up_indexes: [], hand_indexes: [], partner_beans: [])
  end
end
