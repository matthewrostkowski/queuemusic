# features/step_definitions/login_steps.rb

Given("I am on the login page") do
  visit login_path
  expect(page).to have_css("[data-testid='login-form']")
end

When("I continue as guest") do
  click_button "Continue as guest"
end

Then("I should be on the main page") do
  # Use the dev version: check path + main welcome selector
  expect(page).to have_current_path(mainpage_path, ignore_query: true)
  expect(page).to have_selector(Selectors::MAIN_WELCOME)
end

Then("I should see my guest name on the page") do
  # Use the dev version: rely on CURRENT_USER selector
  expect(page.find(Selectors::CURRENT_USER).text).to match(/^Guest\b/)
end

When("I logout") do
  if page.has_link?("Logout")
    click_link "Logout"
  elsif page.has_button?("Logout")
    click_button "Logout"
  else
    click_link "logout", href: logout_path
  end
end

Then("I should be on the login page") do
  expect(current_path).to eq(login_path)
end

Given("I am logged out") do
  clear_session
  visit login_path
end

Given("I am not logged in") do
  clear_session
  visit login_path
end

When("I visit {string}") do |path|
  visit path
end

And("I fill in {string} with {string}") do |field_label, value|
  case field_label
  when "user_email"
    fill_in "user[email]", with: value
  when "user_password"
    fill_in "user[password]", with: value
  when "user_password_confirmation"
    fill_in "user[password_confirmation]", with: value
  when "email"
    fill_in "email", with: value
  when "password"
    fill_in "password", with: value
  else
    fill_in field_label, with: value
  end
end

And("I press {string}") do |button_text|
  click_button button_text
end

Given("I am logged in as {string}") do |name|
  user = User.create!(
    email: "user_#{SecureRandom.hex(4)}@example.com",
    password: "password123",
    password_confirmation: "password123",
    display_name: name,
    auth_provider: "general_user"
  )
  
  set_session_user(user)
  @current_user = user
end

And("a general user exists with email {string} and password {string} and display name {string}") do |email, password, display_name|
  User.create!(
    email: email,
    password: password,
    password_confirmation: password,
    display_name: display_name,
    auth_provider: "general_user"
  )
end

And(/^I sign up with email "([^"]*)" and password "([^"]*)"$/) do |email, password|
  visit "/signup"
  fill_in "user_email", with: email
  fill_in "user_password", with: password
  fill_in "user_password_confirmation", with: password
  click_button "Create account"
end

When("I log out") do
  page.driver.submit :delete, "/logout", {}
end

And(/^I log in with email "([^"]*)" and password "([^"]*)"$/) do |email, password|
  visit "/login"
  within("[data-testid='login-form']") do
    fill_in "email", with: email
    fill_in "password", with: password
    click_button "Sign in"
  end
end
