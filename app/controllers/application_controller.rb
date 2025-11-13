# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  # ---------------------
  # Logging
  # ---------------------
  before_action :log_request_info
  after_action  :log_response_info

  # ---------------------
  # Auth / user
  # ---------------------
  before_action :set_current_user
  # Allow some controllers/actions to be public (login, signup, etc.)
  before_action :authenticate_user!, unless: :public_controller?

  helper_method :current_user, :current_queue_session

  # ---------------------
  # Auth
  # ---------------------
  def authenticate_user!
    Rails.logger.info "[AUTH] authenticate_user! called. current_user: #{current_user&.id}"

    return if current_user.present?

    Rails.logger.warn "[AUTH] No current user. Redirecting to login."
    respond_to do |format|
      format.html { redirect_to login_path, alert: "Please sign in" }
      format.json { render json: { error: "unauthorized" }, status: :unauthorized }
      format.any  { head :unauthorized }
    end
  end

  def require_login
    authenticate_user!
  end

  # Require host or admin
  def require_host!
    Rails.logger.info "[AUTH] require_host! called. current_user: #{current_user&.id}"

    if current_user&.respond_to?(:host_account?) && current_user.host_account?
      Rails.logger.info "[AUTH] User is host-account (role or venues)."
      return
    end

    unless current_user&.host? || current_user&.admin?
      Rails.logger.warn "[AUTH] User is NOT a host. Redirecting."
      respond_to do |format|
        format.html { redirect_to mainpage_path, alert: "You don't have permission to access this page" }
        format.json { render json: { error: "forbidden" }, status: :forbidden }
        format.any  { head :forbidden }
      end
    end
  end

  # Require admin only
  def require_admin!
    unless current_user&.admin?
      respond_to do |format|
        format.html { redirect_to mainpage_path, alert: "Admin access required" }
        format.json { render json: { error: "forbidden" }, status: :forbidden }
        format.any  { head :forbidden }
      end
    end
  end

  # Redirect after sign-in based on role
  def after_sign_in_path
    return login_path unless current_user

    case current_user.role
    when "admin"
      admin_dashboard_path
    when "host"
      # send hosts to their venues index/dashboard
      host_venues_path
    else
      mainpage_path # Regular user
    end
  end

  # ---------------------
  # Current user / queue
  # ---------------------
  private

  def public_controller?
    # Controllers/actions that should NOT force authentication
    controller_name == "login" ||
      controller_name == "sessions" ||
      (controller_name == "users" && %w[new create].include?(action_name))
  end

  def set_current_user
    current_user
  end

  def current_user
    @current_user ||= begin
      user = User.find_by(id: session[:user_id]) if session[:user_id]
      Rails.logger.debug "[USER] current_user lookup: session_id=#{session[:user_id]}, found=#{user.present?}"
      user
    end
  end

  def current_queue_session
    @current_queue_session ||= begin
      # 1) If user joined a specific session via code
      if session[:current_queue_session_id]
        qs = QueueSession.find_by(id: session[:current_queue_session_id])
        Rails.logger.debug "[QUEUE] lookup by session: id=#{session[:current_queue_session_id]}, found=#{qs.present?}, active=#{qs&.active?}"
        return qs if qs&.active?
      end

      # 2) Fallback: global active queue session
      qs = QueueSession.active.first

      # 3) If none exists at all, create a default
      unless qs
        Rails.logger.info "[QUEUE] No active queue session. Creating default."
        venue = Venue.first || Venue.create!(name: "Main Venue")

        attrs = { venue: venue }
        if QueueSession.column_names.include?("is_active")
          attrs[:is_active] = true
        elsif QueueSession.column_names.include?("status")
          attrs[:status] = "active"
        end

        qs = QueueSession.create!(attrs)
      end

      qs
    end
  end

  def set_current_queue_session(queue_session)
    Rails.logger.info "[QUEUE] Setting current_queue_session: #{queue_session.id} (code: #{queue_session.join_code})"
    session[:current_queue_session_id] = queue_session.id
    @current_queue_session = queue_session
  end

  # ---------------------
  # Logging
  # ---------------------
  def log_request_info
    @request_start_time = Time.now
    Rails.logger.info "[REQUEST] #{request.method} #{request.path} | User: #{current_user&.email || 'ANONYMOUS'} | IP: #{request.remote_ip}"
  end

  def log_response_info
    Rails.logger.info "[RESPONSE] Status: #{response.status} | Duration: #{(Time.now - @request_start_time).round(3)}s" rescue nil
  end
end
