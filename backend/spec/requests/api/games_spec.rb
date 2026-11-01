require 'rails_helper'

RSpec.describe 'Api::Games', type: :request do
  describe 'POST /api/games' do
    it "starts a game and shows only the human's hand" do
      post '/api/games', params: { bot_count: 2 }, as: :json

      expect(response).to have_http_status(:created)
      game = response.parsed_body['game']
      expect(game['players'].pluck('name')).to eq(%w[You Pinto Lima])
      expect(game['players'].first['hand'].size).to eq(5)
      expect(game['players'].drop(1).pluck('hand')).to all(be_nil)
      expect(game['players'].drop(1).pluck('hand_size')).to all(eq(5))
      expect(game['bean_types'].size).to eq(8)
      expect(game).to include('phase' => 'plant', 'active_index' => 0, 'over' => false, 'winners' => [])
      expect(game['success_message']).to eq('Cards dealt. Good luck!')
    end

    it 'defaults to 3 smart bots' do
      post '/api/games', as: :json

      expect(response.parsed_body['game']['players'].size).to eq(4)
      expect(response.parsed_body['game']).to include('bot_level' => 'normal', 'offer' => nil)
    end

    it 'plays easy bots when asked' do
      post '/api/games', params: { bot_count: 2, bot_level: 'easy' }, as: :json

      expect(response.parsed_body['game']['bot_level']).to eq('easy')
    end

    it 'rejects a bad bot count' do
      post '/api/games', params: { bot_count: 'lots' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('game' => { 'error_message' => 'Choose 2 to 4 bots' })
    end
  end

  describe 'GET /api/games/:id' do
    it 'returns the saved game' do
      game = Games::Create.new(2, random: Random.new(1)).call[:payload]
      get "/api/games/#{game.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['game']['id']).to eq(game.id)
    end

    it 'lists the winners once the game is over' do
      engine = BeanBazaar::Game.start(names: %w[You Pinto Lima], random: Random.new(1))
      BeanBazaar::BotRunner.new(engine, human_index: nil).run
      game = Game.create!(state: engine.to_h)
      get "/api/games/#{game.id}"

      expect(response.parsed_body['game']['over']).to be(true)
      expect(response.parsed_body['game']['winners']).not_to be_empty
    end

    it "spells out a bot's offer waiting for the human" do
      pinto = BeanBazaar::Player.new(
        name: 'Pinto',
        hand: BeanBazaar::Hand.new(%i[wax]),
        fields: [BeanBazaar::Field.new(bean: :soy, count: 2), BeanBazaar::Field.new(bean: :blue, count: 3)],
      )
      engine = BeanBazaar::Game.new(
        players: [BeanBazaar::Player.new(name: 'You'), pinto, BeanBazaar::Player.new(name: 'Lima')],
        deck: BeanBazaar::Deck.new(draw_pile: Array.new(20, :chili)),
        active_index: 1,
        phase: :trade,
        face_up: BeanBazaar::Hand.new(%i[red]),
      )
      engine.propose(partner_index: 0, face_up_indexes: [0], hand_indexes: [0], partner_beans: %w[blue])
      game = Game.create!(state: engine.to_h)
      get "/api/games/#{game.id}"

      expect(response.parsed_body['game']['offer']).to eq('from' => 1, 'give' => %w[red wax], 'ask' => ['blue'], 'choices' => [])
    end

    it 'hides an offer made to someone else' do
      engine = BeanBazaar::Game.start(names: %w[You Pinto Lima], random: Random.new(1))
      engine.plant_from_hand(0)
      engine.flip_cards
      engine.propose(partner_index: 1, face_up_indexes: [0])
      game = Game.create!(state: engine.to_h)
      get "/api/games/#{game.id}"

      expect(response.parsed_body['game']['offer']).to be_nil
    end

    it 'returns 404 for an unknown game' do
      get '/api/games/0'

      expect(response).to have_http_status(:not_found)
    end
  end
end
