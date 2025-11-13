# app/controllers/host/venues_controller.rb
module Host
  class VenuesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_host!, except: [:new, :create]
    before_action :set_venue, only: [
      :show, :edit, :update, :destroy, 
      :create_session, :start_session, 
      :pause_session, :resume_session, 
      :end_session, :regenerate_code, :dashboard
    ]

    def index
      @venues = current_user.hosted_venues
    end

    def new
      @venue = Venue.new
    end

    def create
      @venue = Venue.new(venue_params)
      @venue.host_user_id = current_user.id
      
      if @venue.save
        redirect_to host_venue_path(@venue), notice: "Venue created successfully!"
      else
        render :new, status: :unprocessable_content
      end
    end

    def show
      authorize_host!(@venue)
      @sessions = @venue.queue_sessions.order(created_at: :desc)
      @active_session = @venue.active_session
    end

    def edit
      authorize_host!(@venue)
    end

    def update
      authorize_host!(@venue)
      
      if @venue.update(venue_params)
        redirect_to host_venue_path(@venue), notice: "Venue updated successfully!"
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize_host!(@venue)
      @venue.destroy
      redirect_to host_venues_path, notice: "Venue deleted successfully"
    end

    def dashboard
      authorize_host!(@venue)
      @active_session = @venue.active_session
      if @active_session
        @queue_items = @active_session.queue_items
                                      .includes(:song)
                                      .order(vote_count: :desc)
      end
    end

    def create_session
      authorize_host!(@venue)
      session = @venue.queue_sessions.build(status: 'active')
      session.join_code = JoinCodeGenerator.generate_unique_code
      
      if session.save
        redirect_to host_venue_path(@venue), notice: "Session started successfully"
      else
        redirect_to host_venue_path(@venue), alert: "Failed to start session"
      end
    end

    def start_session
      authorize_host!(@venue)
      session = @venue.queue_sessions.build(status: 'active')
      session.join_code = JoinCodeGenerator.generate_unique_code
      
      if session.save
        redirect_to host_venue_path(@venue), notice: "Session started!"
      else
        redirect_to host_venue_path(@venue), alert: "Error starting session"
      end
    end

    def pause_session
      authorize_host!(@venue)
      active_session = @venue.active_session
      
      if active_session && active_session.update(status: 'paused')
        redirect_to host_venue_path(@venue), notice: "Session paused"
      else
        redirect_to host_venue_path(@venue), alert: "Could not pause session"
      end
    end

    def resume_session
      authorize_host!(@venue)
      paused_session = @venue.queue_sessions.find_by(status: 'paused')
      
      if paused_session && paused_session.update(status: 'active')
        redirect_to host_venue_path(@venue), notice: "Session resumed"
      else
        redirect_to host_venue_path(@venue), alert: "Could not resume session"
      end
    end

    def end_session
      authorize_host!(@venue)
      active_session = @venue.active_session
      
      if active_session && active_session.update(status: 'ended')
        redirect_to host_venue_path(@venue), notice: "Session ended"
      else
        redirect_to host_venue_path(@venue), alert: "Could not end session"
      end
    end

    def regenerate_code
      authorize_host!(@venue)
      active_session = @venue.active_session
      
      if active_session
        active_session.update(join_code: JoinCodeGenerator.generate_unique_code)
        redirect_to host_venue_path(@venue), notice: "Code regenerated"
      else
        redirect_to host_venue_path(@venue), alert: "No active session"
      end
    end

    private

    def set_venue
      @venue = Venue.find(params[:id])
    end

    def venue_params
      params.require(:venue).permit(:name, :location, :capacity)
    end

    def authorize_host!(venue)
      unless venue.host_user_id == current_user.id
        redirect_to mainpage_path, alert: "You are not authorized to manage this venue"
      end
    end
  end
end