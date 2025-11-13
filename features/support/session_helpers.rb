# features/support/session_helpers.rb
# Proper session handling for Capybara + RackTest + Rails

module SessionHelpers
  # Set a user session without making HTTP requests
  def set_session_user(user)
    page.driver.browser.env["rack.session"] ||= {}
    page.driver.browser.env["rack.session"]["user_id"] = user.id
  end

  # Clear the session completely (logout effect)
  def clear_session
    page.driver.browser.env["rack.session"] = {}
  end

  # Helper to visit a page as a specific user
  def visit_as_user(path, user)
    set_session_user(user)
    visit path
  end
end

def clear_session(*_args)
  if page.driver.browser.respond_to?(:rack_test_session)
    page.driver.browser.rack_test_session.cookie_jar.clear
  end
  Capybara.reset_sessions! if defined?(Capybara)
end


# Include these helpers in all Capybara feature tests
World(SessionHelpers)