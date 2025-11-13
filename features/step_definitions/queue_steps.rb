# frozen_string_literal: true

Given("a clean queue session") do
  QueueItem.delete_all
  QueueSession.delete_all

  host = User.create!(
    display_name: "QueueHost",
    auth_provider: "guest"
  )

  @venue = Venue.create!(
    name: "Test Venue",
    host_user_id: host.id
  )

  @session = @venue.queue_sessions.create!(
    status: "active",
    started_at: Time.current,
    join_code: JoinCodeGenerator.generate
  )
end

When("I visit the search page") do
  visit "/search"
end

Then("I should see a search form") do
  expect(page).to have_css("form")
  expect(page).to have_css("input[type='text'], input[type='search']")
end

When("I POST a new queue item titled {string} by {string}") do |title, artist|
  session = QueueSession.where(status: "active").first || begin
    venue = Venue.first || Venue.create!(name: "Default Venue")
    QueueSession.create!(
      venue: venue,
      status: "active",
      started_at: Time.current,
      join_code: JoinCodeGenerator.generate
    )
  end

  params = {
    title: title,
    artist: artist,
    cover_url: "https://example.test/cover.jpg",
    duration_ms: 180_000,
    preview_url: "https://example.test/preview.mp3",
    user_display_name: "TestUser",
    spotify_id: "123456",
    vote_score: 0,
    queue_session_id: session.id
  }

  page.driver.submit :post, "/queue_items", params
end

When("I visit the queue page") do
  visit "/queue"
end

Then("I should see {string} on the queue page") do |text|
  expect(page).to have_text(text)
end

Given("a queued item titled {string} by {string}") do |title, artist|
  session = QueueSession.where(status: "active").first || begin
    venue = Venue.first || Venue.create!(name: "Default Venue")
    QueueSession.create!(
      venue: venue,
      status: "active",
      started_at: Time.current,
      join_code: JoinCodeGenerator.generate
    )
  end

  QueueItem.create!(
    queue_session: session,
    title: title,
    artist: artist,
    cover_url: "https://example.test/cover.jpg",
    duration_ms: 180_000,
    preview_url: "https://example.test/preview.mp3",
    user_display_name: "Seeder",
    vote_score: 0,
    status: "pending",
    spotify_id: "123456"
  )
end

When("I upvote the item titled {string}") do |title|
  item = QueueItem.where(title: title).order(created_at: :desc).first
  raise "QueueItem not found for title #{title}" unless item

  # Hit the real Rails member route with a simple path string
  page.driver.submit :post, "/queue_items/#{item.id}/upvote", {}
end

Then("the database vote score for {string} should be {string}") do |title, expected|
  item = QueueItem.where(title: title).order(created_at: :desc).first
  expect(item).not_to be_nil
  item.reload
  expect(item.vote_score.to_s).to eq(expected)
end
