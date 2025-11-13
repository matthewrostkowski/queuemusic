# app/models/user.rb
class User < ApplicationRecord
  # =====================
  # Roles
  # =====================
  # Ensure enum works even if role column isn't present yet in some schemas
  attribute :role, :integer, default: 0
  enum :role, { user: 0, host: 1, admin: 2 }

  # =====================
  # Associations
  # =====================
  has_many :queue_items, dependent: :nullify
  has_many :queued_songs, through: :queue_items, source: :song

  # Host-side association (your host branch)
  has_many :hosted_venues,
           class_name:  "Venue",
           foreign_key: "host_user_id",
           dependent:   :destroy

  # From dev: wallet / accounting system
  has_many :balance_transactions, dependent: :destroy

  # =====================
  # Authentication
  # =====================
  has_secure_password validations: false

  # =====================
  # Validations
  # =====================
  validates :display_name,  presence: true
  validates :auth_provider, presence: true
  
  validates :email,
            format:     { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true },
            uniqueness: { case_sensitive: false, allow_blank: true }

  # Only validate canonical_email if the column actually exists in this schema.
  if column_names.include?("canonical_email")
    validates :canonical_email,
              uniqueness: { case_sensitive: false, allow_blank: true }
  end

  # For general_user provider, require email and password
  validates :email, presence: true,
            if: -> { auth_provider == "general_user" }

  # Use dev's stricter length + "changed password" behavior
  validates :password, presence: true, length: { minimum: 8 },
            if: -> { auth_provider == "general_user" && (new_record? || password.present?) }

  # =====================
  # Callbacks
  # =====================
  before_validation :normalize_and_canonicalize_email

  # =====================
  # Balance Management
  # =====================
  def balance
    balance_cents.to_i / 100.0
  end
  
  def balance_display
    "$#{'%.2f' % balance}"
  end
  
  def has_sufficient_balance?(amount_cents)
    balance_cents.to_i >= amount_cents.to_i
  end
  
  # Deduct amount from balance (for queue payments)
  def debit_balance!(amount_cents, description: nil, queue_item: nil)
    raise "Insufficient balance" unless has_sufficient_balance?(amount_cents)
    
    transaction do
      new_balance = balance_cents.to_i - amount_cents.to_i
      update!(balance_cents: new_balance)
      
      balance_transactions.create!(
        amount_cents:        -amount_cents,
        transaction_type:    "debit",
        description:         description || "Queue payment",
        queue_item:          queue_item,
        balance_after_cents: new_balance
      )
    end
  end
  
  # Add amount to balance (for refunds or credits)
  def credit_balance!(amount_cents, description: nil, queue_item: nil)
    transaction do
      new_balance = balance_cents.to_i + amount_cents.to_i
      update!(balance_cents: new_balance)
      
      balance_transactions.create!(
        amount_cents:        amount_cents,
        transaction_type:    "refund",
        description:         description || "Queue refund",
        queue_item:          queue_item,
        balance_after_cents: new_balance
      )
    end
  end
  
  # Initialize balance for new users
  def initialize_balance!
    return if balance_transactions.exists?
    
    transaction do
      balance_transactions.create!(
        amount_cents:        10_000,
        transaction_type:    "initial",
        description:         "Welcome bonus",
        balance_after_cents: balance_cents
      )
    end
  end

  # =====================
  # Class Methods
  # =====================
  def self.find_or_create_guest(name = nil)
    display_name = name || "Guest_#{SecureRandom.hex(4)}"
    Rails.logger.info "[USER] find_or_create_guest called name_param=#{name.inspect} generated_display_name=#{display_name.inspect}"

    user = create(display_name: display_name, auth_provider: "guest", role: :user)

    if user.persisted?
      Rails.logger.info "[USER] Guest user created id=#{user.id} display_name=#{user.display_name.inspect}"
    else
      Rails.logger.error "[USER] Guest user creation FAILED errors=#{user.errors.full_messages.join(' | ')}"
    end

    user
  end

  # =====================
  # Instance Methods
  # =====================
  def total_upvotes_received
    sum = queue_items.sum(:vote_count)
    Rails.logger.debug "[USER] total_upvotes_received user_id=#{id.inspect} sum=#{sum}"
    sum
  end

  def queue_summary
    summary = {
      username:      display_name,
      queued_count:  queue_items.count,
      upvotes_total: total_upvotes_received
    }
    Rails.logger.debug "[USER] queue_summary user_id=#{id.inspect} summary=#{summary.inspect}"
    summary
  end

  def is_host?
    hosted = hosted_venues.any?
    Rails.logger.debug "[USER] is_host? user_id=#{id.inspect} hosted_venues_count=#{hosted_venues.size} result=#{hosted}"
    hosted
  end

  # Richer helper used by ApplicationController
  def host_account?
    result = host? || admin? || hosted_venues.exists?
    Rails.logger.debug "[USER] host_account? user_id=#{id.inspect} role=#{role.inspect} hosted_venues_count=#{hosted_venues.size} result=#{result}"
    result
  end

  # =====================
  # Private Helpers
  # =====================
  private

  def normalize_and_canonicalize_email
    Rails.logger.debug "[USER] normalize_and_canonicalize_email START user_id=#{id || 'NEW'} raw_email=#{self.email.inspect}"

    # Normalize email -> strip + downcase
    if email.present?
      self.email = email.to_s.strip.downcase
    else
      self.email = nil
    end

    # Only try to touch canonical_email if:
    #  1) email present, AND
    #  2) this schema actually has a canonical_email column
    if email.present?
      if self.class.column_names.include?("canonical_email")
        begin
          canon = canonicalize_email(email)
          self[:canonical_email] = canon
          Rails.logger.debug "[USER] canonical_email SET user_id=#{id || 'NEW'} canonical_email=#{canon.inspect}"
        rescue => e
          Rails.logger.error "[USER] ERROR setting canonical_email user_id=#{id || 'NEW'} error=#{e.class}: #{e.message}"
        end
      else
        Rails.logger.debug "[USER] canonical_email column MISSING in schema; skipping canonicalization for email=#{email.inspect}"
      end
    else
      Rails.logger.debug "[USER] normalize_and_canonicalize_email: email is blank, skipping canonicalization"
    end

    Rails.logger.debug "[USER] normalize_and_canonicalize_email END user_id=#{id || 'NEW'} normalized_email=#{email.inspect}"
  end

  def canonicalize_email(raw)
    Rails.logger.debug "[USER] canonicalize_email called raw=#{raw.inspect}"
    return nil if raw.blank?

    email = raw.to_s.strip.downcase
    local, domain = email.split("@", 2)
    unless local && domain
      Rails.logger.debug "[USER] canonicalize_email invalid format; returning original=#{email.inspect}"
      return email
    end

    # Gmail-style canonicalization: ignore tags & dots in local part
    local  = local.split("+", 2)[0]
    local  = local.delete(".")
    result = "#{local}@#{domain}"

    Rails.logger.debug "[USER] canonicalize_email result=#{result.inspect}"
    result
  end
end
