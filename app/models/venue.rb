# app/models/venue.rb
class Venue < ApplicationRecord
  # Host who owns/manages this venue
  belongs_to :host_user,
             class_name:  "User",
             foreign_key: "host_user_id",
             optional:    true

  has_many :queue_sessions,
           class_name:  "QueueSession",
           foreign_key: :venue_id,
           dependent:   :destroy

  validates :name, presence: true

  # Specs expect host_user_id presence validation
  validates :host_user_id, presence: true

  # Active queue session for this venue
  def active_queue_session
    Rails.logger.info "[VENUE] active_queue_session venue_id=#{id.inspect}"
    session = queue_sessions.active.first
    Rails.logger.info "[VENUE] active_queue_session venue_id=#{id.inspect} active_queue_session_id=#{session&.id.inspect}"
    session
  end

  # Host::VenuesController sometimes calls active_session
  alias_method :active_session, :active_queue_session

  # Simple hook to log validation problems clearly
  after_validation :log_validation_state

  private

  def log_validation_state
    if errors.any?
      Rails.logger.warn "[VENUE] validation FAILED venue_id=#{id.inspect} name=#{name.inspect} host_user_id=#{host_user_id.inspect} errors=#{errors.full_messages.join('; ')}"
    else
      Rails.logger.info "[VENUE] validation OK venue_id=#{id.inspect} name=#{name.inspect} host_user_id=#{host_user_id.inspect}"
    end
  end
end
