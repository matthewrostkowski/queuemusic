# Get current user after login from login_steps.rb
def current_user
  @current_user ||= User.find_by(display_name: @username) if @username
end

Given('I am not logged in') do
  @current_user = nil
  # Clear any existing session
  page.driver.delete logout_path if page.respond_to?(:driver)
end

Given('a venue {string} with an active queue session exists') do |venue_name|
  host = User.create!(
    display_name: 'ProfileHost',
    auth_provider: 'guest'
  )

  @venue = Venue.create!(
    name: venue_name,
    location: '123 Test St',
    capacity: 200,
    host_user_id: host.id
  )

  @queue_session = @venue.queue_sessions.create!(
    status: 'active',
    started_at: Time.current,
    join_code: JoinCodeGenerator.generate
  )
end

Given('I have queued the song {string} by {string}') do |title, artist|
  song = Song.find_or_create_by!(title: title, artist: artist)
  user = User.last # Get the user created by login step
  @queue_item = QueueItem.create!(
    user: user,
    song: song,
    queue_session: @queue_session,
    base_price: 3.99,
    vote_count: 0,
    status: 'pending'
  )
end

Given('that song has received {int} upvotes') do |upvotes|
  @queue_item.update!(vote_count: upvotes)
end

Given('I have queued the song {string} by {string} with status {string}') do |title, artist, status|
  song = Song.find_or_create_by!(title: title, artist: artist)
  user = User.last # Get the user created by login step
  @queue_item = QueueItem.create!(
    user: user,
    song: song,
    queue_session: @queue_session,
    base_price: 3.99,
    vote_count: 0,
    status: status
  )
end

Given('that song has a base price of {string}') do |price|
  @queue_item.update!(base_price: price.gsub('$', '').to_f)
end

Given('I have queued the following songs:') do |table|
  user = User.last # Get the user created by login step
  @queued_songs = table.hashes
  table.hashes.each do |row|
    song = Song.find_or_create_by!(title: row['title'], artist: row['artist'])
    QueueItem.create!(
      user: user,
      song: song,
      queue_session: @queue_session,
      base_price: 3.99,
      vote_count: row['upvotes'].to_i,
      status: row['status']
    )
  end
end

When('I visit my profile page') do
  visit profile_path
end

When('I try to visit the profile page') do
  visit profile_path
end

Then('I should see my username {string}') do |username|
  expect(page).to have_content(username)
end

Then('I should see {string} songs queued') do |count|
  expect(page).to have_content(count)
  expect(page).to have_content('Songs Queued')
end

Then('I should see {string} total upvotes') do |count|
  expect(page).to have_content(count)
  expect(page).to have_content('Total Upvotes')
end

Then('I should see {string}') do |text|
  expect(page).to have_content(text)
end

Then('I should see the song {string}') do |title|
  expect(page).to have_content(title)
end

Then('I should see {string} upvotes for that song') do |upvotes|
  expect(page).to have_content("👍")
  expect(page).to have_content(upvotes)
end

Then("I should see all {int} songs listed") do |count|
  # The Given step should have saved the table as @queued_songs = table.hashes
  expect(@queued_songs&.size).to eq(count)

  @queued_songs.each do |row|
    title  = row.fetch("title")
    artist = row.fetch("artist")
    # Match the rendered "Title — Artist" line (or adjust if your separator differs)
    expect(page).to have_text(title)
    expect(page).to have_text(artist)
  end
end


Then('I should see a status badge showing {string}') do |status|
  expect(page.text.downcase).to include(status.downcase)
end

Then('I should see a price displayed for that song') do
  expect(page).to have_content('$')
end

Then('I should see an unauthorized message') do
  # App redirects to login page when unauthorized
  expect(page).to have_current_path('/login', ignore_query: true)
  expect(page).to have_content('Please sign in')
end
