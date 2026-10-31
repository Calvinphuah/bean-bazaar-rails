module Api
  class MovesController < ApplicationController
    def create
      game = Games::MoveService.new(game: Game.find(params[:game_id]), move: move_params).call
      render json: GameSerializer.new(game)
    end

    private

    def move_params
      params.expect(move: [ :type, :field_index, :pending_index, :partner_index,
                            face_up_indexes: [], hand_indexes: [], partner_beans: [] ])
    end
  end
end
