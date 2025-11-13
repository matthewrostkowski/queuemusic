# app/models/queue_session.rb
class QueueSession < ApplicationRecord
  belongs_to :venue

  has_many :queue_items,
           class_name:  "QueueItem",
           foreign_key: :queue_session_id,
           dependent:   :destroy

  has_many :songs, through: :queue_items
  has_many :users, through: :queue_items

  belongs_to :currently_playing_track,
             class_name:  "QueueItem",
             foreign_key: :currently_playing_id,
             optional:    true

  VALID_STATUSES = %w[active paused ended].freeze

  # ---------------------
  # Scopes / state
  # ---------------------
  scope :active, -> {
    if column_names.include?("status")
      where(status: "active")
    else
      where(is_active: true)
    end
  }

  validates :venue, presence: true

  if column_names.include?("join_code")
    validates :join_code, presence: true
  end

  if column_names.include?("status")
    validates :status, inclusion: { in: VALID_STATUSES }
  end

  if column_names.include?("access_code")
    validates :access_code, uniqueness: true, allow_nil: true
  end

  before_create :assign_join_code
  before_create :set_default_started_at

  # ---------------------
  # CLASS-LEVEL OVERRIDE for create!
  # ---------------------
  class << self
    # Ensure that join_code/access_code is assigned *before* validations
    # when someone calls QueueSession.create!(...) without a code,
    # like in venues_controller_spec.
    def create!(*args, &block)
      obj = new(*args, &block)

      Rails.logger.info "[QUEUE_SESSION.create!] NEW attrs=#{obj.attributes.slice('venue_id', 'join_code', 'access_code', 'status').inspect}"

      if needs_code?(obj)
        obj.send(:assign_join_code)
        Rails.logger.info "[QUEUE_SESSION.create!] ASSIGNED code join_code=#{obj[:join_code].inspect} access_code=#{obj[:access_code].inspect}"
      else
        Rails.logger.info "[QUEUE_SESSION.create!] PRESERVED existing code join_code=#{obj[:join_code].inspect} access_code=#{obj[:access_code].inspect}"
      end

      obj.save!
      obj
    end

    private

    def needs_code?(obj)
      (obj.class.column_names.include?("join_code") && obj[:join_code].blank?) &&
        (!obj.class.column_names.include?("access_code") || obj[:access_code].blank?)
    end
  end

  # ---------------------
  # Playback helpers
  # ---------------------

  # Get the queue in priority order
  def ordered_queue
    scope = queue_items
      .where(played_at: nil)
      .includes(:song, :user)

    Rails.logger.info "[QUEUE_SESSION] ordered_queue session_id=#{id.inspect} pending_count=#{scope.size}"
    scope.sort_by { |qi| -qi.score.to_i }
  end

  def next_track
    track = ordered_queue.first
    Rails.logger.info "[QUEUE_SESSION] next_track session_id=#{id.inspect} next_queue_item_id=#{track&.id.inspect}"
    track
  end

  def play_track!(queue_item)
    Rails.logger.info "[QUEUE_SESSION] play_track! session_id=#{id.inspect} queue_item_id=#{queue_item&.id.inspect}"
    transaction do
      queue_items.update_all(is_currently_playing: false)

      queue_item.update!(
        is_currently_playing: true,
        played_at:            Time.current
      )

      attrs = {
        currently_playing_id: queue_item.id,
        playback_started_at:  Time.current
      }
      attrs[:is_playing] = true if self.class.column_names.include?("is_playing")

      Rails.logger.info "[QUEUE_SESSION] play_track! update session_id=#{id.inspect} attrs=#{attrs.inspect}"
      update!(attrs)
    end
  rescue => e
    Rails.logger.error "[QUEUE_SESSION] play_track! ERROR session_id=#{id.inspect} queue_item_id=#{queue_item&.id.inspect} error=#{e.class}: #{e.message}"
    raise
  end

  def stop_playback!
    Rails.logger.info "[QUEUE_SESSION] stop_playback! session_id=#{id.inspect}"
    transaction do
      queue_items.update_all(is_currently_playing: false)

      attrs = {
        currently_playing_id: nil,
        playback_started_at:  nil
      }
      attrs[:is_playing] = false if self.class.column_names.include?("is_playing")

      Rails.logger.info "[QUEUE_SESSION] stop_playback! update session_id=#{id.inspect} attrs=#{attrs.inspect}"
      update!(attrs)
    end
  rescue => e
    Rails.logger.error "[QUEUE_SESSION] stop_playback! ERROR session_id=#{id.inspect} error=#{e.class}: #{e.message}"
    raise
  end

  def play_next!
    Rails.logger.info "[QUEUE_SESSION] play_next! session_id=#{id.inspect}"
    next_up = next_track
    if next_up
      play_track!(next_up)
      next_up
    else
      stop_playback!
      nil
    end
  end

  def songs_count
    count = queue_items.where(played_at: nil).count
    Rails.logger.info "[QUEUE_SESSION] songs_count session_id=#{id.inspect} count=#{count}"
    count
  end

  def started_at
    value =
      if self.class.column_names.include?("started_at") && self[:started_at].present?
        self[:started_at]
      elsif respond_to?(:playback_started_at) && playback_started_at.present?
        playback_started_at
      else
        created_at
      end

    Rails.logger.info "[QUEUE_SESSION] started_at reader session_id=#{id.inspect} db_started_at=#{self[:started_at].inspect} playback_started_at=#{respond_to?(:playback_started_at) ? playback_started_at.inspect : 'n/a'} created_at=#{created_at.inspect} resolved=#{value.inspect}"
    value
  end

  def current_item
    item = currently_playing_track || queue_items.find_by(is_currently_playing: true)
    Rails.logger.info "[QUEUE_SESSION] current_item session_id=#{id.inspect} queue_item_id=#{item&.id.inspect}"
    item
  end

  def current_song_title
    current_item&.title
  end

  def current_song_artist
    current_item&.artist
  end

  def active?
    result =
      if respond_to?(:status) && status.present?
        status == "active"
      elsif respond_to?(:is_active)
        !!is_active
      else
        true
      end

    Rails.logger.info "[QUEUE_SESSION] active? session_id=#{id.inspect} status=#{respond_to?(:status) ? status.inspect : 'n/a'} is_active=#{respond_to?(:is_active) ? is_active.inspect : 'n/a'} result=#{result}"
    result
  end

  def join_code
    code =
      if self.class.column_names.include?("join_code") && self[:join_code].present?
        self[:join_code]
      else
        self[:access_code]
      end

    Rails.logger.info "[QUEUE_SESSION] join_code reader session_id=#{id.inspect} join_code=#{self[:join_code].inspect} access_code=#{self[:access_code].inspect} resolved=#{code.inspect}"
    code
  end

  private

  def assign_join_code
    return unless self.class.column_names.include?("join_code") || self.class.column_names.include?("access_code")

    Rails.logger.info "[QUEUE_SESSION] assign_join_code BEFORE session_id=#{id.inspect} join_code=#{self[:join_code].inspect} access_code=#{self[:access_code].inspect}"

    if self[:join_code].blank? && (!self.class.column_names.include?("access_code") || self[:access_code].blank?)
      generated = JoinCodeGenerator.generate
      self[:join_code]   = generated if self.class.column_names.include?("join_code")
      self[:access_code] = generated if self.class.column_names.include?("access_code")
      Rails.logger.info "[QUEUE_SESSION] assign_join_code GENERATED session_id=#{id.inspect} code=#{generated.inspect}"
    else
      Rails.logger.info "[QUEUE_SESSION] assign_join_code PRESERVED existing codes join_code=#{self[:join_code].inspect} access_code=#{self[:access_code].inspect}"
    end
  rescue => e
    Rails.logger.error "[QUEUE_SESSION] assign_join_code ERROR session_id=#{id.inspect} error=#{e.class}: #{e.message}"
    raise
  end

  def set_default_started_at
    return unless self.class.column_names.include?("started_at")

    Rails.logger.info "[QUEUE_SESSION] set_default_started_at BEFORE session_id=#{id.inspect} started_at=#{self[:started_at].inspect}"
    if self[:started_at].nil?
      self[:started_at] = Time.current
      Rails.logger.info "[QUEUE_SESSION] set_default_started_at ASSIGNED session_id=#{id.inspect} started_at=#{self[:started_at].inspect}"
    else
      Rails.logger.info "[QUEUE_SESSION] set_default_started_at PRESERVED session_id=#{id.inspect} started_at=#{self[:started_at].inspect}"
    end
  rescue => e
    Rails.logger.error "[QUEUE_SESSION] set_default_started_at ERROR session_id=#{id.inspect} error=#{e.class}: #{e.message}"
    raise
  end
end
