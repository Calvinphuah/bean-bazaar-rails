module Api
  class GamesController < ApplicationController
    DEFAULT_BOT_COUNT = 3

    def create
      game = Games::StartService.new(bot_count: bot_count).call
      render json: GameSerializer.new(game), status: :created
    end

    def show
      render json: GameSerializer.new(Game.find(params[:id]))
    end

    private

    def bot_count
      Integer(params.fetch(:bot_count, DEFAULT_BOT_COUNT))
    rescue ArgumentError, TypeError
      raise BeanBazaar::IllegalMove, "bot_count must be a number"
    end
  end
end
