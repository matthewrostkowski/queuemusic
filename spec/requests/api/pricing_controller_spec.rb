# frozen_string_literal: true
require "rails_helper"

RSpec.describe Api::PricingController, type: :request do
  let!(:venue) { Venue.create!(name: "Test Venue") }
  let!(:queue_session) { QueueSession.create!(venue:, is_active: true) }

  describe "GET /api/pricing/current_prices" do
    before do
      allow(DynamicPricingService).to receive(:calculate_position_price) do |_qs, pos|
        100 * pos # 1..10 -> 100,200,...,1000
      end
      allow(DynamicPricingService).to receive(:get_pricing_factors) do |_qs|
        { demand: 0.8, surge: 1.2 }
      end
    end

    it "returns 200 with 10 positions and formatted price when queue_session_id is provided" do
      get "/api/pricing/current_prices", params: { queue_session_id: queue_session.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["queue_session_id"]).to eq(queue_session.id)
      expect(json["positions"]).to be_an(Array).and have_attributes(length: 10)

      first = json["positions"].first
      last  = json["positions"].last
      expect(first).to include("position" => 1, "price_cents" => 100, "price_display" => "$1.00")
      expect(last).to  include("position" => 10, "price_cents" => 1000, "price_display" => "$10.00")

      expect(json["factors"]).to eq({ "demand" => 0.8, "surge" => 1.2 })
    end

    it "auto-creates a default queue session when none found and still returns 200" do
      QueueSession.delete_all
      Venue.delete_all

      expect {
        get "/api/pricing/current_prices"
      }.to change { QueueSession.count }.by(1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["queue_session_id"]).to be_present
      expect(json["positions"]).to be_an(Array).and have_attributes(length: 10)
    end
  end

  describe "GET /api/pricing/position_price" do
    before do
      allow(DynamicPricingService).to receive(:calculate_position_price).and_return(123) # 1.23
      allow(DynamicPricingService).to receive(:get_pricing_factors).and_return({ crowd: 50 })
    end

    it "returns 200 with price and factors when position > 0" do
      get "/api/pricing/position_price", params: { queue_session_id: queue_session.id, position: 3 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to include(
        "position" => 3,
        "price_cents" => 123,
        "price_display" => "$1.23",
        "factors" => { "crowd" => 50 }
      )
    end

    it "returns 400 when position is invalid" do
      get "/api/pricing/position_price", params: { queue_session_id: queue_session.id, position: 0 }

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Invalid queue session or position")
    end

    it "auto-creates queue session when not provided and position > 0" do
      QueueSession.delete_all
      Venue.delete_all

      expect {
        get "/api/pricing/position_price", params: { position: 2 }
      }.to change { QueueSession.count }.by(1)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/pricing/factors" do
    before do
      allow(DynamicPricingService).to receive(:get_pricing_factors).and_return({ surge: 1.1, base: 100 })
    end

    it "returns 200 with factors when queue_session_id is provided" do
      get "/api/pricing/factors", params: { queue_session_id: queue_session.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eq({ "surge" => 1.1, "base" => 100 })
    end

    it "auto-creates queue session when none exist and returns 200" do
      QueueSession.delete_all
      Venue.delete_all

      expect {
        get "/api/pricing/factors"
      }.to change { QueueSession.count }.by(1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eq({ "surge" => 1.1, "base" => 100 })
    end
  end
end
