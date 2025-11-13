# app/controllers/main_controller.rb
class MainController < ApplicationController
  before_action :authenticate_user!

  def index
    # From host branch: keep current_user + current_queue_session
    @user = current_user
    @queue_session = current_queue_session

    # From dev branch: list active sessions for dashboards/host views
    @sessions = QueueSession
                  .active
                  .includes(:venue, :queue_items, :currently_playing_track)
                  .order(created_at: :desc)
  end
end
