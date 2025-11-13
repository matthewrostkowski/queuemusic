# app/controllers/host_venues_controller.rb
class HostVenuesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_host!
  before_action :set_venue, only: [:show, :edit, :update, :destroy, :create_session]
  
  def index
    @venues = current_user.hosted_venues
  end

  def new
    @venue = Venue.new
  end

  def create
    @venue = current_user.hosted_venues.build(venue_params)
    
    if @venue.save
      redirect_to host_venue_path(@venue), notice: "Venue created successfully!"
    else
      render :new, status: :unprocessable_content
    end
  end

  def show
    @queue_sessions = @venue.queue_sessions.order(created_at: :desc)
    @active_session = @venue.queue_sessions.find_by(status: 'active')
  end

  def edit
  end

  def update
    if @venue.update(venue_params)
      redirect_to host_venue_path(@venue), notice: "Venue updated successfully!"
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @venue.destroy
    redirect_to host_venues_path, notice: "Venue deleted successfully!"
  end

  # Create a new queue session for the venue
  def create_session
    @existing_active = @venue.queue_sessions.find_by(status: 'active')
    
    if @existing_active
      redirect_to host_venue_path(@venue), alert: "An active session already exists for this venue"
      return
    end

    join_code = QueueSession.generate_join_code
    @session = @venue.queue_sessions.create(
      status: 'active',
      join_code: join_code
    )

    if @session.persisted?
      redirect_to host_venue_path(@venue), notice: "Session started successfully!"
    else
      redirect_to host_venue_path(@venue), alert: "Failed to start session"
    end
  end

  # Pause an active session
  def pause_session
    @session = QueueSession.find(params[:session_id])
    @session.update(status: 'paused')
    redirect_to host_venue_path(@venue), notice: "Session paused"
  end

  # End a session
  def end_session
    @session = QueueSession.find(params[:session_id])
    @session.update(status: 'ended')
    redirect_to host_venue_path(@venue), notice: "Session ended"
  end

  # Regenerate join code for a session
  def regenerate_code
    @session = QueueSession.find(params[:session_id])
    new_code = QueueSession.generate_join_code
    @session.update(join_code: new_code)
    redirect_to host_venue_path(@venue), notice: "Code regenerated"
  end

  private

  def set_venue
    @venue = Venue.find(params[:id] || params[:venue_id])
  end

  def venue_params
    params.require(:venue).permit(:name, :location, :capacity)
  end
end