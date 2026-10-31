require 'rails_helper'

RSpec.describe 'Api::Moves', type: :request do
  let(:game) { Games::Create.new(2, random: Random.new(1)).call[:payload] }

  it 'applies a move and returns the new state' do
    post "/api/games/#{game.id}/moves", params: { move: { type: 'plant_from_hand', field_index: 0 } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['game']['hand_plants']).to eq(1)
    expect(response.parsed_body['game']['players'].first['hand'].size).to eq(4)
  end

  it 'returns the rule broken as a 422' do
    post "/api/games/#{game.id}/moves", params: { move: { type: 'flip_cards' } }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq('game' => { 'error_message' => 'Plant the front card of your hand first' })
  end

  it 'returns 400 without a move' do
    post "/api/games/#{game.id}/moves", params: {}, as: :json

    expect(response).to have_http_status(:bad_request)
  end

  it 'returns 404 for an unknown game' do
    post '/api/games/0/moves', params: { move: { type: 'flip_cards' } }, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
