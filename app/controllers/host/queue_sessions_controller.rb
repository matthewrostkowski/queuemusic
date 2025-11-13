# app/controllers/host/queue_sessions_controller.rb
class Host::QueueSessionsController < ApplicationController
  before_action :require_login
  before_action :set_queue_session, only: [:pause, :resume, :end]
  before_action :authorize_host!, only: [:pause, :resume, :end]

  # POST /host/venues/:venue_id/queue_sessions
  def create
    venue = Venue.find(params[:venue_id])
    authorize_venue!(venue)

    if venue.active_session
      render json: { error: "Session already active" }, status: :unprocessable_entity
      return
    end

    session_record = venue.queue_sessions.create!(status: 'active', started_at: Time.current)
    render json: { join_code: session_record.join_code, session_id: session_record.id }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PATCH /host/queue_sessions/:id/pause
  def pause
    @queue_session.pause!
    render json: { status: @queue_session.status }
  end

  # PATCH /host/queue_sessions/:id/resume
  def resume
    @queue_session.resume!
    render json: { status: @queue_session.status }
  end

  # PATCH /host/queue_sessions/:id/end
  def end
    @queue_session.end_session!
    render json: { status: @queue_session.status }
  end

  private

  def set_queue_session
    @queue_session = QueueSession.find(params[:id])
  end

  def authorize_venue!(venue)
    redirect_to mainpage_path, alert: "Not authorized." unless venue.host_user == current_user
  end

  def authorize_host!
    venue = @queue_session.venue
    redirect_to mainpage_path, alert: "Not authorized." unless venue.host_user == current_user
  end
end