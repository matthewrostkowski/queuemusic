# app/controllers/scan_controller.rb
class ScanController < ApplicationController
  def index
    @error = nil
  end

  # POST /join or /scan - User enters a join code
  def join_by_code
    code = params[:join_code].to_s.strip.presence || params[:code].to_s.strip

    # Validate format
    unless JoinCodeGenerator.valid_format?(code)
      @error = "Invalid code format. Please enter a 6-digit code."
      return render :index
    end

    # Find active session with this code (handles join_code/access_code internally)
    session_record = JoinCodeGenerator.find_active_session(code)
    unless session_record
      @error = "Code not found or session is no longer active. Please try again."
      return render :index
    end

    # Store in session and redirect to queue
    set_current_queue_session(session_record)
    redirect_to queue_path, notice: "Welcome to #{session_record.venue.name}! 🎵"
  rescue => e
    Rails.logger.error("Error joining queue: #{e.message}")
    @error = "An error occurred. Please try again."
    render :index
  end

  # Backwards compatibility if anything calls ScanController#create
  alias_method :create, :join_by_code
end
