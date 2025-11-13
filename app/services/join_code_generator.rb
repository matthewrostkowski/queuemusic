# app/services/join_code_generator.rb
class JoinCodeGenerator
  # Generate a unique 6-digit code
  def self.generate
    loop do
      code = "%06d" % SecureRandom.random_number(1_000_000)
      break code unless code_taken?(code)
    end
  end

  # Backwards-compatible alias
  def self.generate_unique_code
    generate
  end

  def self.valid_format?(code)
    code.to_s.match?(/^\d{6}$/)
  end

  # Find an active session whose join/access code matches
  def self.find_active_session(code)
    return nil unless valid_format?(code)

    QueueSession.active.find_by(join_code: code) ||
      QueueSession.active.find_by(access_code: code)
  end

  class << self
    private

    def code_taken?(code)
      taken = false
      if QueueSession.column_names.include?("join_code")
        taken ||= QueueSession.exists?(join_code: code)
      end
      if QueueSession.column_names.include?("access_code")
        taken ||= QueueSession.exists?(access_code: code)
      end
      taken
    end
  end
end

