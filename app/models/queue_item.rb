# app/models/queue_item.rb
class QueueItem < ApplicationRecord
  belongs_to :queue_session
  belongs_to :song, optional: true
  belongs_to :user, optional: true

  # Validations
  validates :status, inclusion: { in: %w[pending playing played] }, allow_nil: true
  
  # Make base_price_cents optional for test scenarios
  validates :base_price_cents, numericality: { greater_than: 0 }, allow_nil: true
  
  # Validate that we have either a song OR direct title/artist
  validate :must_have_song_or_title_artist, on: :create
  
  # Set defaults
  before_validation :set_defaults, on: :create
  
  # Scopes
  scope :unplayed, -> { where(status: "pending") }
  scope :played,   -> { where(status: "played") }

  # From dev: explicit position + vote_score ordering
  scope :by_position, -> { order(:base_priority, :created_at) } # For display
  scope :by_votes,    -> { order(:base_priority, vote_score: :desc, created_at: :asc) } # For playback
  
  # Override attribute readers to check both song and direct attributes
  def title
    read_attribute(:title) || song&.title
  end
  
  def artist
    read_attribute(:artist) || song&.artist
  end
  
  def preview_url
    read_attribute(:preview_url) || song&.preview_url
  end
  
  def cover_url
    song&.cover_url
  end
  
  def duration_ms
    song&.duration_ms
  end
  
  def spotify_id
    song&.spotify_id
  end
  
  # Helper method to work with dollars
  def base_price
    return 0.0 if base_price_cents.nil?
    base_price_cents / 100.0
  end
  
  def base_price=(dollars)
    self.base_price_cents = (dollars.to_f * 100).to_i
  end

  # Used by profile view: simple wrapper around base_price with logging
  def price_for_display
    dollars = base_price
    Rails.logger.info "[QUEUE_ITEM] price_for_display queue_item_id=#{id.inspect} base_price_cents=#{base_price_cents.inspect} dollars=#{dollars.inspect}"
    dollars
  end
  
  # Pricing and position methods
  def effective_cost
    position_paid_cents.to_i - refund_amount_cents.to_i
  end
  
  def was_bumped?
    return false unless inserted_at_position && position_guaranteed
    inserted_at_position != current_position_in_queue
  end
  
  def current_position_in_queue
    return nil unless queue_session

    # Get position among unplayed items
    unplayed_items = queue_session.queue_items
                                  .where(played_at: nil)
                                  .where(status: "pending")
                                  .order(:base_priority, :created_at)
                                  .pluck(:id)

    position = unplayed_items.index(id)
    position ? position + 1 : nil  # Convert to 1-indexed
  end

  # Price to jump ahead of this item (insert at its current position)
  def jump_ahead_price_cents
    @jump_ahead_price || 0
  end

  def jump_ahead_price_display
    price = jump_ahead_price_cents
    price > 0 ? "$#{'%.2f' % (price / 100.0)}" : "Free"
  end
  
  private
  
  def set_defaults
    Rails.logger.info "[QUEUE_ITEM] set_defaults BEFORE queue_item_id=#{id.inspect} base_price_cents=#{base_price_cents.inspect} vote_count=#{vote_count.inspect} vote_score=#{vote_score.inspect} base_priority=#{base_priority.inspect} status=#{status.inspect}"
    self.base_price_cents ||= 0
    self.vote_count       ||= 0
    self.vote_score       ||= 0
    self.base_priority    ||= 0
    self.status           ||= "pending"
    Rails.logger.info "[QUEUE_ITEM] set_defaults AFTER queue_item_id=#{id.inspect} base_price_cents=#{base_price_cents.inspect} vote_count=#{vote_count.inspect} vote_score=#{vote_score.inspect} base_priority=#{base_priority.inspect} status=#{status.inspect}"
  end
  
  def must_have_song_or_title_artist
    if song_id.blank? && (read_attribute(:title).blank? || read_attribute(:artist).blank?)
      Rails.logger.warn "[QUEUE_ITEM] must_have_song_or_title_artist FAILED queue_item_id=#{id.inspect} song_id=nil title=#{read_attribute(:title).inspect} artist=#{read_attribute(:artist).inspect}"
      errors.add(:base, "Must have either a song or title/artist")
    end
  end
end
