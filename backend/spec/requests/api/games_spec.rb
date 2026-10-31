require "rails_helper"

RSpec.describe "Api::Games", type: :request do
  describe "POST /api/games" do
    it "starts a game and shows only the human's hand" do
      post "/api/games", params: { bot_count: 2 }, as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["players"].pluck("name")).to eq(%w[You Pinto Lima])
      expect(body["players"].first["hand"].size).to eq(5)
      expect(body["players"].drop(1).pluck("hand")).to all(be_nil)
      expect(body["players"].drop(1).pluck("hand_size")).to all(eq(5))
      expect(body["bean_types"].size).to eq(8)
      expect(body).to include("phase" => "plant", "active_index" => 0, "over" => false, "winners" => [])
    end

    it "defaults to 3 bots" do
      post "/api/games", as: :json

      expect(response.parsed_body["players"].size).to eq(4)
    end

    it "rejects a bad bot count" do
      post "/api/games", params: { bot_count: "lots" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("error" => "bot_count must be a number")
    end
  end

  describe "GET /api/games/:id" do
    it "returns the saved game" do
      game = Games::StartService.new(bot_count: 2, random: Random.new(1)).call
      get "/api/games/#{game.id}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(game.id)
    end

    it "lists the winners once the game is over" do
      engine = BeanBazaar::Game.start(names: %w[You Pinto Lima], random: Random.new(1))
      BeanBazaar::BotRunner.new(engine, human_index: nil).run
      game = Game.create!(state: engine.to_h)
      get "/api/games/#{game.id}"

      expect(response.parsed_body["over"]).to be(true)
      expect(response.parsed_body["winners"]).not_to be_empty
    end

    it "returns 404 for an unknown game" do
      get "/api/games/0"

      expect(response).to have_http_status(:not_found)
    end
  end
end
