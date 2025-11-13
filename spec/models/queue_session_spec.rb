require 'rails_helper'

RSpec.describe QueueSession, type: :model do
  let(:host) do
    User.create!(
      display_name: 'Test Host',
      auth_provider: 'general_user',
      email: 'host@test.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  let(:venue) do
    Venue.create!(
      name: 'Test Venue',
      location: 'NYC',
      capacity: 200,
      host_user_id: host.id
    )
  end

  describe 'associations' do
    it 'belongs to venue' do
      association = QueueSession.reflect_on_association(:venue)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'has many queue_items' do
      association = QueueSession.reflect_on_association(:queue_items)
      expect(association.macro).to eq(:has_many)
    end
  end

  describe 'validations' do
    it 'validates presence of venue' do
      session = QueueSession.new(status: 'active', join_code: '123456')
      expect(session).not_to be_valid
      expect(session.errors[:venue]).to include("must exist")
    end

    it 'validates presence of join_code' do
      session = QueueSession.new(venue: venue, status: 'active')
      expect(session).not_to be_valid
      expect(session.errors[:join_code]).to include("can't be blank")
    end

    it 'is valid with venue and join_code' do
      session = QueueSession.new(
        venue: venue,
        status: 'active',
        join_code: '123456',
        started_at: Time.current
      )
      expect(session).to be_valid
    end

    it 'validates status is one of allowed values' do
      session = QueueSession.new(
        venue: venue,
        status: 'invalid_status',
        join_code: '123456'
      )
      expect(session).not_to be_valid
    end
  end

  describe 'join_code' do
    it 'validates presence of join_code' do
      session = QueueSession.new(venue: venue, status: 'active')
      expect(session).not_to be_valid
      expect(session.errors[:join_code]).to include("can't be blank")
    end

    it 'generates a 6-digit code' do
      code = JoinCodeGenerator.generate
      session = QueueSession.create!(
        venue: venue,
        status: 'active',
        join_code: code,
        started_at: Time.current
      )
      expect(session.join_code.length).to eq(6)
      expect(session.join_code).to match(/^\d{6}$/)
    end

    it 'allows updating the join code' do
      code = JoinCodeGenerator.generate
      session = QueueSession.create!(
        venue: venue,
        status: 'active',
        join_code: code,
        started_at: Time.current
      )
      new_code = JoinCodeGenerator.generate
      session.update(join_code: new_code)
      expect(session.join_code).to eq(new_code)
    end
  end

  describe 'status' do
    it 'allows active status' do
      session = QueueSession.new(
        venue: venue,
        status: 'active',
        join_code: '123456'
      )
      expect(session).to be_valid
    end

    it 'allows paused status' do
      session = QueueSession.new(
        venue: venue,
        status: 'paused',
        join_code: '123456'
      )
      expect(session).to be_valid
    end

    it 'allows ended status' do
      session = QueueSession.new(
        venue: venue,
        status: 'ended',
        join_code: '123456'
      )
      expect(session).to be_valid
    end

    it 'rejects invalid status' do
      session = QueueSession.new(
        venue: venue,
        status: 'invalid',
        join_code: '123456'
      )
      expect(session).not_to be_valid
    end
  end

  describe 'timestamps' do
    it 'records started_at' do
      code = JoinCodeGenerator.generate
      start_time = 1.hour.ago
      session = QueueSession.create!(
        venue: venue,
        status: 'active',
        join_code: code,
        started_at: start_time
      )
      expect(session.started_at).to eq(start_time)
    end

    it 'records ended_at when session ends' do
      code = JoinCodeGenerator.generate
      session = QueueSession.create!(
        venue: venue,
        status: 'active',
        join_code: code,
        started_at: Time.current
      )
      end_time = Time.current
      session.update(status: 'ended', ended_at: end_time)
      expect(session.ended_at).to be_present
    end

    it 'allows nil ended_at for active sessions' do
      code = JoinCodeGenerator.generate
      session = QueueSession.create!(
        venue: venue,
        status: 'active',
        join_code: code,
        started_at: Time.current
      )
      expect(session.ended_at).to be_nil
    end
  end

  describe 'scopes' do
    let(:code1) { JoinCodeGenerator.generate }
    let(:code2) { JoinCodeGenerator.generate }
    let(:code3) { JoinCodeGenerator.generate }

    before do
      QueueSession.create!(
        venue: venue,
        status: 'active',
        join_code: code1,
        started_at: Time.current
      )
      QueueSession.create!(
        venue: venue,
        status: 'paused',
        join_code: code2,
        started_at: 1.hour.ago
      )
      QueueSession.create!(
        venue: venue,
        status: 'ended',
        join_code: code3,
        started_at: 1.day.ago,
        ended_at: 1.day.ago + 2.hours
      )
    end

    it 'filters active sessions' do
      active = QueueSession.where(status: 'active')
      expect(active.count).to eq(1)
    end

    it 'filters ended sessions' do
      ended = QueueSession.where(status: 'ended')
      expect(ended.count).to eq(1)
    end

    it 'finds session by join_code' do
      session = QueueSession.find_by(join_code: code2)
      expect(session.status).to eq('paused')
    end
  end

  describe 'creation' do
    it 'can be created with all attributes' do
      code = JoinCodeGenerator.generate
      session = QueueSession.create!(
        venue: venue,
        status: 'active',
        join_code: code,
        started_at: Time.current
      )
      expect(session.venue_id).to eq(venue.id)
      expect(session.status).to eq('active')
      expect(session.join_code).to eq(code)
      expect(session.started_at).to be_present
    end
  end

  describe 'relationships' do
    let(:session) do
      QueueSession.create!(
        venue: venue,
        status: 'active',
        join_code: '123456',
        started_at: Time.current
      )
    end

    it 'can have queue items' do
      user = User.create!(display_name: 'Test User', auth_provider: 'guest')
      song = Song.create!(title: 'Test Song', artist: 'Test Artist')
      
      queue_item = QueueItem.create!(
        user: user,
        song: song,
        queue_session: session,
        base_price: 3.99
      )
      
      expect(session.queue_items).to include(queue_item)
    end

    it 'destroys associated queue_items when session is deleted' do
      user = User.create!(display_name: 'Test User', auth_provider: 'guest')
      song = Song.create!(title: 'Test Song', artist: 'Test Artist')
      
      queue_item = QueueItem.create!(
        user: user,
        song: song,
        queue_session: session,
        base_price: 3.99
      )
      
      session.destroy
      expect(QueueItem.find_by(id: queue_item.id)).to be_nil
    end
  end
end