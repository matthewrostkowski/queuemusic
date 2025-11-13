require "rails_helper"

RSpec.describe "VenuesController", type: :request do
  let!(:user)  { User.create!(display_name: "SpecUser", auth_provider: "guest") }
  let!(:host) { User.create!(display_name: "Host", auth_provider: "guest") }
  let!(:venue) { Venue.create!(name: "Queue House", location: "Somewhere", capacity: 100, host_user_id: host.id) }

  before { login_as(user) }

  it "shows a venue" do
    active = QueueSession.create!(venue: venue, is_active: true)

    get "/venues/#{venue.id}", as: :json
    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body)
    expect(body["venue"]).to include(
      "id" => venue.id,
      "name" => "Queue House",
      "location" => "Somewhere",
      "capacity" => 100
    )
    expect(body["queue_session"]).to include("id" => active.id, "is_active" => true)
  end
end
