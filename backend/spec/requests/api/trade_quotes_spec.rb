require 'rails_helper'

RSpec.describe 'Api::TradeQuotes', type: :request do
  let(:game) { Games::Create.new(2, random: Random.new(1)).call[:payload] }

  before do
    engine = game.engine
    engine.plant_from_hand(engine.players.first.fields.index { |field| field.accepts?(engine.players.first.hand.front) })
    engine.flip_cards
    game.store(engine)
  end

  it "returns each bot's answer" do
    post "/api/games/#{game.id}/trade_quotes", params: { quote: { face_up_indexes: [0] } }, as: :json

    expect(response).to have_http_status(:ok)
    answers = response.parsed_body['quote']['answers']
    expect(answers.pluck('player')).to eq([1, 2])
    expect(answers.pluck('answer')).to all(be_in(%w[accept decline missing]))
  end

  it 'returns the rule broken as a 422' do
    post "/api/games/#{game.id}/trade_quotes", params: { quote: { face_up_indexes: [9] } }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to eq('quote' => { 'error_message' => 'There is no card at position 9' })
  end

  it 'treats a missing quote as an empty offer' do
    post "/api/games/#{game.id}/trade_quotes", as: :json

    expect(response).to have_http_status(:ok)
  end
end
