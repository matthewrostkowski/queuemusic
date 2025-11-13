require "rails_helper"

RSpec.describe User, type: :model do
  describe 'associations' do
    it 'has many queue_items' do
      association = User.reflect_on_association(:queue_items)
      expect(association.macro).to eq(:has_many)
    end

    it 'has many queued_songs through queue_items' do
      association = User.reflect_on_association(:queued_songs)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:through]).to eq(:queue_items)
      expect(association.options[:source]).to eq(:song)
    end

    it 'has many hosted_venues' do
      association = User.reflect_on_association(:hosted_venues)
      expect(association.macro).to eq(:has_many)
    end
  end

  describe 'validations' do
    it "is valid with display_name and auth_provider" do
      u = User.new(display_name: "Guest", auth_provider: "guest")
      expect(u).to be_valid
    end

    it "is invalid without display_name" do
      u = User.new(auth_provider: "guest")
      expect(u).not_to be_valid
      expect(u.errors[:display_name]).to be_present
    end

    it "is invalid without auth_provider" do
      u = User.new(display_name: "X")
      expect(u).not_to be_valid
      expect(u.errors[:auth_provider]).to be_present
    end

    it "allows guest without email/password" do
      u = User.new(auth_provider: "guest", display_name: "Guest X")
      expect(u).to be_valid
    end

    it "requires email/password for general_user" do
      u = User.new(auth_provider: "general_user", display_name: "X")
      expect(u).not_to be_valid
      u.email = "a@b.com"
      u.password = "12345678"
      u.password_confirmation = "12345678"
      expect(u).to be_valid
    end

    it "downcases email" do
      u = User.create!(auth_provider: "general_user", display_name: "X",
                       email: "HELLO@TEST.COM", password: "12345678", password_confirmation: "12345678")
      expect(u.reload.email).to eq("hello@test.com")
    end
  end

  describe '#authenticate' do
    let(:user) do
      User.create!(
        auth_provider: "general_user",
        display_name: "Test User",
        email: "test@example.com",
        password: "correct_password",
        password_confirmation: "correct_password"
      )
    end

    it "returns user when password is correct" do
      expect(user.authenticate("correct_password")).to eq(user)
    end

    it "returns false when password is incorrect" do
      expect(user.authenticate("wrong_password")).to be_falsey
    end

    it "is case sensitive for passwords" do
      expect(user.authenticate("Correct_password")).to be_falsey
    end
  end

  describe '#total_upvotes_received' do
    let(:user) { User.create!(display_name: 'TestUser', auth_provider: 'guest') }
    let(:host) do
      User.create!(
        display_name: 'Host',
        auth_provider: 'general_user',
        email: 'host@test.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
    end
    let(:venue) do
      Venue.create!(
        name: 'Test Venue',
        location: '123 Test St',
        capacity: 200,
        host_user_id: host.id
      )
    end
    let(:session) do
      venue.queue_sessions.create!(
        status: 'active',
        started_at: Time.current,
        join_code: '123456'
      )
    end

    context 'when user has no queue items' do
      it 'returns 0' do
        expect(user.total_upvotes_received).to eq(0)
      end
    end

    context 'when user has queue items with votes' do
      before do
        song1 = Song.create!(title: 'Song 1', artist: 'Artist 1')
        song2 = Song.create!(title: 'Song 2', artist: 'Artist 2')
        
        QueueItem.create!(
          user: user,
          song: song1,
          queue_session: session,
          base_price: 3.99,
          vote_count: 5
        )
        
        QueueItem.create!(
          user: user,
          song: song2,
          queue_session: session,
          base_price: 4.99,
          vote_count: 10
        )
      end

      it 'returns sum of all vote counts' do
        expect(user.total_upvotes_received).to eq(15)
      end
    end

    context 'when user has queue items with zero votes' do
      before do
        song = Song.create!(title: 'Song', artist: 'Artist')
        QueueItem.create!(
          user: user,
          song: song,
          queue_session: session,
          base_price: 3.99,
          vote_count: 0
        )
      end

      it 'returns 0' do
        expect(user.total_upvotes_received).to eq(0)
      end
    end
  end

  describe '#queue_summary' do
    let(:user) { User.create!(display_name: 'TestUser', auth_provider: 'guest') }

    it 'returns hash with username, songs count, and upvotes' do
      summary = user.queue_summary

      expect(summary).to be_a(Hash)
      expect(summary[:username]).to eq('TestUser')
      expect(summary[:queued_count]).to eq(0)
      expect(summary[:upvotes_total]).to eq(0)
    end

    context 'with queue items' do
      before do
        host = User.create!(
          display_name: 'Host',
          auth_provider: 'general_user',
          email: 'host@test.com',
          password: 'password123',
          password_confirmation: 'password123'
        )
        venue = Venue.create!(name: 'Test', location: '123 St', capacity: 200, host_user_id: host.id)
        session = venue.queue_sessions.create!(status: 'active', started_at: Time.current, join_code: '123456')
        song = Song.create!(title: 'Test', artist: 'Artist')
        
        QueueItem.create!(
          user: user,
          song: song,
          queue_session: session,
          base_price: 3.99,
          vote_count: 7
        )
      end

      it 'returns correct counts' do
        summary = user.queue_summary

        expect(summary[:queued_count]).to eq(1)
        expect(summary[:upvotes_total]).to eq(7)
      end
    end
  end

  describe '#is_host?' do
    it "returns true if user has hosted venues" do
      host = User.create!(
        display_name: 'Host',
        auth_provider: 'general_user',
        email: 'host@test.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
      host.hosted_venues.create!(name: 'Venue 1', location: 'NYC', capacity: 100)
      
      expect(host.is_host?).to be_truthy
    end

    it "returns false if user has no hosted venues" do
      user = User.create!(display_name: 'User', auth_provider: 'guest')
      
      expect(user.is_host?).to be_falsey
    end
  end

  describe 'email uniqueness' do
    it "prevents duplicate emails" do
      User.create!(
        auth_provider: "general_user",
        display_name: "User 1",
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123"
      )

      duplicate = User.new(
        auth_provider: "general_user",
        display_name: "User 2",
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123"
      )

      expect(duplicate).not_to be_valid
    end

    it "is case-insensitive for email uniqueness" do
      User.create!(
        auth_provider: "general_user",
        display_name: "User 1",
        email: "Test@Example.Com",
        password: "password123",
        password_confirmation: "password123"
      )

      duplicate = User.new(
        auth_provider: "general_user",
        display_name: "User 2",
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123"
      )

      expect(duplicate).not_to be_valid
    end
  end

  describe 'scopes' do
    before do
      User.create!(display_name: 'Guest1', auth_provider: 'guest')
      User.create!(
        display_name: 'Host1',
        auth_provider: 'general_user',
        email: 'host@test.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
    end

    it 'finds user by email' do
      user = User.find_by(email: 'host@test.com')
      expect(user.display_name).to eq('Host1')
    end

    it 'finds user by display_name' do
      user = User.find_by(display_name: 'Guest1')
      expect(user.auth_provider).to eq('guest')
    end
  end
end