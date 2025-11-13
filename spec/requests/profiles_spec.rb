require 'rails_helper'

RSpec.describe "Profiles", type: :request do
  let(:user) { User.create!(display_name: 'TestUser', auth_provider: 'guest') }
  
  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticate_user!).and_return(true)
  end

  describe "GET /profile" do
    it "returns http success" do
      get profile_path
      expect(response).to have_http_status(:success)
    end

    it "displays username" do
      get profile_path
      expect(response.body).to include('@TestUser')
    end

    it "displays stats section" do
      get profile_path
      expect(response.body).to include('Songs Queued')
      expect(response.body).to include('Total Upvotes')
    end

    context "with no queue items" do
      it "shows empty state" do
        get profile_path
        expect(response.body).to include("You haven't queued any songs yet")
      end

      it "shows zero stats" do
        get profile_path
        expect(response.body).to include('0')
      end
    end

    context "with queue items" do
      before do
        host = User.create!(display_name: 'Host', auth_provider: 'guest')
      venue = Venue.create!(name: 'Test', location: '123 St', capacity: 200, host_user_id: host.id)
        session = venue.queue_sessions.create!(status: "active", started_at: Time.current, join_code: JoinCodeGenerator.generate)
        song = Song.create!(title: 'Blinding Lights', artist: 'The Weeknd')
        
        QueueItem.create!(
          user: user,
          song: song,
          queue_session: session,
          base_price: 3.99,
          vote_count: 10,
          status: 'pending'
        )
      end

      it "displays song title" do
        get profile_path
        expect(response.body).to include('Blinding Lights')
      end

      it "displays artist name" do
        get profile_path
        expect(response.body).to include('The Weeknd')
      end

      it "displays upvote count" do
        get profile_path
        expect(response.body).to include('👍')
        expect(response.body).to include('10')
      end

      it "displays status badge" do
        get profile_path
        expect(response.body).to include('pending')
      end
    end
  end
end