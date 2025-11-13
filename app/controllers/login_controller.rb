# app/controllers/login_controller.rb
class LoginController < ApplicationController
  # =====================
  # NO callbacks needed - we manually check in the action
  # =====================

  # GET /login
  def index
    Rails.logger.info "[LOGIN] Page requested"
    
    # If user is already logged in, redirect to appropriate page
    if current_user
      Rails.logger.info "[LOGIN] User already authenticated: #{current_user.email} - Redirecting to mainpage"
      redirect_to mainpage_path
      return
    end
    
    Rails.logger.info "[LOGIN] Rendering login form"
    # Render the login page template
  end
end