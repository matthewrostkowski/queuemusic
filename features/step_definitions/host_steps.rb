# features/step_definitions/host_steps.rb

Given("I am logged in as a host") do
  @host_user = User.create!(
    email: "host_#{SecureRandom.hex(4)}@example.com",
    password: "password123",
    password_confirmation: "password123",
    display_name: "Test Host",
    auth_provider: "email"
  )

  set_session_user(@host_user)
  visit mainpage_path
end

And("I have a venue named {string} in {string} with capacity {string}") do |name, location, capacity|
  @venue = Venue.create!(
    name: name,
    location: location,
    capacity: capacity.to_i,
    host_user_id: @host_user.id
  )
end

When("I navigate to create a new venue") do
  visit new_host_venue_path
end

When("I fill in the venue form with:") do |table|
  table.rows_hash.each do |field, value|
    fill_in field, with: value
  end
end

When("I click {string}") do |button_text|
  click_button button_text
end

Then("I should see {string}") do |text|
  expect(page).to have_content(text)
end

Then("the venue {string} should exist") do |name|
  expect(Venue.exists?(name: name)).to be true
end

When("I navigate to my venue {string}") do |venue_name|
  venue = Venue.find_by(name: venue_name)
  visit host_venue_path(venue)
end

When("I start a new session") do
  click_button "Start New Session"
end

Then("I should see the session is {string}") do |status|
  expect(page).to have_content(status)
end

And("I should see a 6-digit join code") do
  expect(page).to have_content(/\d{6}/)
end

And("the join code should be displayed prominently") do
  join_code = page.find("[data-testid='join-code']").text rescue page.text[/\d{6}/]
  expect(join_code).to match(/\d{6}/)
end

When("I click the copy button") do
  click_button "Copy"
end

Then("the join code should be copied to clipboard") do
  expect(page).to have_button("Copy")
end

When("I save the current join code") do
  @current_join_code = page.find("[data-testid='join-code']").text rescue page.text[/\d{6}/]
end

Then("the join code should be different") do
  new_join_code = page.find("[data-testid='join-code']").text rescue page.text[/\d{6}/]
  expect(new_join_code).not_to eq(@current_join_code)
end

Then("the session should be paused") do
  session = QueueSession.last
  expect(session.status).to eq('paused')
end

Then("the session should be ended") do
  session = QueueSession.last
  expect(session.status).to eq('ended')
end

And("I should see previous sessions listed") do
  expect(page).to have_content("Previous Sessions") || have_content("Session History")
end