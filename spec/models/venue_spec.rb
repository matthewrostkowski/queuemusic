require 'rails_helper'

RSpec.describe Venue, type: :model do
  let(:host) do
    User.create!(
      display_name: 'Test Host',
      auth_provider: 'general_user',
      email: 'host@test.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  describe 'associations' do
    it 'has many queue_sessions' do
      association = Venue.reflect_on_association(:queue_sessions)
      expect(association.macro).to eq(:has_many)
    end

    it 'belongs to host_user' do
      association = Venue.reflect_on_association(:host_user)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:class_name]).to eq('User')
      # Handle both string and symbol for foreign_key
      fk = association.options[:foreign_key]
      expect([fk, fk.to_s]).to include('host_user_id')
    end
  end

  describe 'validations' do
    it 'validates presence of name' do
      venue = Venue.new(host_user_id: host.id)
      expect(venue).not_to be_valid
      expect(venue.errors[:name]).to include("can't be blank")
    end

    it 'validates presence of host_user_id' do
      venue = Venue.new(name: 'Test Venue')
      expect(venue).not_to be_valid
      expect(venue.errors[:host_user_id]).to include("can't be blank")
    end

    it 'is valid with name and host_user_id' do
      venue = Venue.new(name: 'Test Venue', host_user_id: host.id)
      expect(venue).to be_valid
    end
  end

  describe 'creation' do
    it 'can be created with all attributes' do
      venue = Venue.create!(
        name: 'Test Venue',
        location: '123 Test St',
        capacity: 100,
        host_user_id: host.id
      )
      expect(venue.name).to eq('Test Venue')
      expect(venue.location).to eq('123 Test St')
      expect(venue.capacity).to eq(100)
      expect(venue.host_user_id).to eq(host.id)
    end
  end

  describe '#active_session' do
    let(:venue) do
      Venue.create!(
        name: 'Test Venue',
        location: 'NYC',
        capacity: 200,
        host_user_id: host.id
      )
    end

    it 'returns the active queue session' do
      active_session = venue.queue_sessions.create!(
        status: 'active',
        started_at: Time.current,
        join_code: '123456'
      )
      expect(venue.active_session).to eq(active_session)
    end

    it 'returns nil if no active session' do
      expect(venue.active_session).to be_nil
    end

    it 'returns first active session when multiple exist' do
      paused = venue.queue_sessions.create!(
        status: 'paused',
        started_at: Time.current,
        join_code: '111111'
      )
      active = venue.queue_sessions.create!(
        status: 'active',
        started_at: Time.current,
        join_code: '222222'
      )
      expect(venue.active_session).to eq(active)
      expect(venue.active_session).not_to eq(paused)
    end

    it 'ignores ended sessions' do
      ended = venue.queue_sessions.create!(
        status: 'ended',
        started_at: Time.current,
        ended_at: Time.current,
        join_code: '333333'
      )
      expect(venue.active_session).to be_nil
    end
  end

  describe 'queue_sessions relationship' do
    let(:venue) do
      Venue.create!(
        name: 'Test Venue',
        location: 'Brooklyn',
        capacity: 150,
        host_user_id: host.id
      )
    end

    it 'can have multiple queue sessions' do
      session1 = venue.queue_sessions.create!(
        status: 'ended',
        started_at: 1.day.ago,
        ended_at: 1.day.ago + 2.hours,
        join_code: '111111'
      )
      session2 = venue.queue_sessions.create!(
        status: 'active',
        started_at: Time.current,
        join_code: '222222'
      )
      
      expect(venue.queue_sessions.count).to eq(2)
      expect(venue.queue_sessions).to include(session1, session2)
    end

    it 'destroys associated queue_sessions when venue is deleted' do
      session = venue.queue_sessions.create!(
        status: 'active',
        started_at: Time.current,
        join_code: '123456'
      )
      
      venue.destroy
      expect(QueueSession.find_by(id: session.id)).to be_nil
    end
  end

  describe 'scopes' do
    before do
      Venue.create!(name: 'Venue 1', host_user_id: host.id)
      other_host = User.create!(
        display_name: 'Other Host',
        auth_provider: 'general_user',
        email: 'other@test.com',
        password: 'password123',
        password_confirmation: 'password123'
      )
      Venue.create!(name: 'Venue 2', host_user_id: other_host.id)
    end

    it 'finds venues by name' do
      venue = Venue.find_by(name: 'Venue 1')
      expect(venue.host_user_id).to eq(host.id)
    end

    it 'finds venues by host_user_id' do
      venues = Venue.where(host_user_id: host.id)
      expect(venues.count).to eq(1)
      expect(venues.first.name).to eq('Venue 1')
    end
  end
end