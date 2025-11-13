require "rails_helper"

RSpec.describe "QueueItemsController", type: :request do
  let!(:user)  { User.create!(display_name: "SpecUser", auth_provider: "guest") }
  let!(:host) { User.create!(display_name: "Host", auth_provider: "guest") }
  let!(:venue) { Venue.create!(name: "SpecVenue", host_user_id: host.id) }
  let!(:qs) { QueueSession.create!(venue: venue, status: "active", started_at: Time.current, join_code: JoinCodeGenerator.generate) }
  let!(:song1) { Song.create!(title: "Alpha", artist: "A") }
  let!(:song2) { Song.create!(title: "Beta",  artist: "B") }

  before { login_as(user) }

  describe "GET /queue_items?queue_session_id=..." do
    it "returns pending items ordered by base_priority, created_at" do
      qi1 = QueueItem.create!(song: song1, queue_session: qs, user: user, base_price: 1.0, vote_count: 1, base_priority: 0, status: "pending")
      sleep 0.01
      qi2 = QueueItem.create!(song: song2, queue_session: qs, user: user, base_price: 1.0, vote_count: 2, base_priority: 0, status: "pending")

      get "/queue_items", params: { queue_session_id: qs.id }, as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.map { |h| h["id"] }).to eq([qi1.id, qi2.id]) # Ordered by base_priority then created_at
      expect(body.first).to include("price_for_display")
      expect(body.first["song"]).to include("title", "artist")
    end

    it "returns 422 when queue_session_id is missing" do
      get "/queue_items", as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /queue_items" do
    it "creates a queue item via search form params" do
      expect {
        post "/queue_items",
             params: { spotify_id: song1.spotify_id, title: song1.title, artist: song1.artist,
                      cover_url: song1.cover_url, duration_ms: song1.duration_ms, preview_url: song1.preview_url,
                      paid_amount_cents: 300, desired_position: 1 },
             as: :json
      }.to change(QueueItem, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body).to include("id", "price_for_display")
    end

    it "rejects creation when user has insufficient balance" do
      # Set user balance to very low
      user.update!(balance_cents: 50)

      expect {
        post "/queue_items",
             params: { spotify_id: song2.spotify_id, title: song2.title, artist: song2.artist,
                      cover_url: song2.cover_url, duration_ms: song2.duration_ms, preview_url: song2.preview_url,
                      paid_amount_cents: 300, desired_position: 1 },
             as: :json
      }.to_not change(QueueItem, :count)

      expect(response).to have_http_status(:payment_required)
      body = JSON.parse(response.body)
      expect(body).to include("error", "balance", "required")
    end
  end

  describe "PATCH /queue_items/:id/vote" do
    it "increments vote_count by delta" do
      qi = QueueItem.create!(song: song1, queue_session: qs, user: user, base_price: 1.0, vote_count: 0)
      patch "/queue_items/#{qi.id}/vote", params: { delta: 1 }, as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("votes" => 1)
      expect(qi.reload.vote_count).to eq(1)
    end
  end
end
