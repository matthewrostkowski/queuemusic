require "rails_helper"

RSpec.describe "QueueItems", type: :request do
  let!(:host) { User.create!(display_name: "Host", auth_provider: "guest") }
  let!(:venue) { Venue.create!(name: "V", host_user_id: host.id) }
  let!(:session) { QueueSession.create!(venue: venue, status: "active", started_at: Time.current, join_code: JoinCodeGenerator.generate) }
  let!(:user)    { User.create!(display_name: "TestUser", auth_provider: "guest") }

  before { login_as(user) }

  it "creates an item from the search form params" do
    params = {
      spotify_id: "3420418861",
      title: "Sofia",
      artist: "Clairo",
      cover_url: "https://example.com/cover.jpg",
      duration_ms: 188000,
      preview_url: "https://example.com/sofia.mp3",
      user_display_name: "Guest",
      desired_position: 1,
      paid_amount_cents: 100  # Provide payment amount
    }
    post "/queue_items", params: params
    expect(response).to have_http_status(:found) # redirected to /queue
    expect(QueueItem.count).to eq(1)
    expect(QueueItem.first.title).to eq("Sofia")
  end

  it "upvotes and returns the new score" do
    qi = QueueItem.create!(queue_session: session, user: user, title: "Test", artist: "Artist", vote_score: 2)
    post "/queue_items/#{qi.id}/upvote", as: :json
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["vote_score"]).to eq(3)
  end

  it "downvotes and returns the new score" do
    qi = QueueItem.create!(queue_session: session, user: user, title: "Test", artist: "Artist", vote_score: 2)
    post "/queue_items/#{qi.id}/downvote", as: :json
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["vote_score"]).to eq(1)
  end

  it "destroys a queue item" do
    qi = QueueItem.create!(queue_session: session, user: user, title: "Song", artist: "Artist")
    delete "/queue_items/#{qi.id}", as: :json
    expect(response).to have_http_status(:ok)
    expect(QueueItem.exists?(qi.id)).to be(false)
  end
end
