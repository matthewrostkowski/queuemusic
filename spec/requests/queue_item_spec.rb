require "rails_helper"

RSpec.describe QueueItem, type: :model do
  let(:host) { User.create!(display_name: "Host", auth_provider: "guest") }
  let(:venue) { Venue.create!(name: "Test Venue", host_user_id: host.id) }
  let(:session) { venue.queue_sessions.create!(status: "active", started_at: Time.current, join_code: "123456") }

  it "is valid with title and artist" do
    qi = QueueItem.new(queue_session: session, title: "Song", artist: "Artist")
    expect(qi).to be_valid
  end

  it "orders by base_priority asc, then created_at asc (for display)" do
    # Create items with different priorities - votes should not affect display order
    paid_item = QueueItem.create!(queue_session: session, title: "Paid", artist: "A", base_priority: 1, vote_score: 1, created_at: 3.minutes.ago)
    high_vote = QueueItem.create!(queue_session: session, title: "High Vote", artist: "A", base_priority: 2, vote_score: 3, created_at: 2.minutes.ago)
    low_vote = QueueItem.create!(queue_session: session, title: "Low Vote", artist: "A", base_priority: 2, vote_score: 1, created_at: 1.minute.ago)
    expect(QueueItem.by_position).to eq([paid_item, high_vote, low_vote])
  end

  it "orders by base_priority asc, then vote_score desc, then created_at asc (for playback)" do
    # Create items with different priorities and vote scores
    paid_item = QueueItem.create!(queue_session: session, title: "Paid", artist: "A", base_priority: 1, vote_score: 1, created_at: 3.minutes.ago)
    high_vote = QueueItem.create!(queue_session: session, title: "High Vote", artist: "A", base_priority: 2, vote_score: 3, created_at: 2.minutes.ago)
    low_vote = QueueItem.create!(queue_session: session, title: "Low Vote", artist: "A", base_priority: 2, vote_score: 1, created_at: 1.minute.ago)
    expect(QueueItem.by_votes).to eq([paid_item, high_vote, low_vote])
  end
end
