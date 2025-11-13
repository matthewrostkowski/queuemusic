# spec/controllers/search_controller_spec.rb
require "rails_helper"

RSpec.describe SearchController, type: :controller do
  render_views

  let(:user) { User.create!(auth_provider: "guest", display_name: "SpecGuest") }

  # --- 這段是關鍵：在測試期間動態新增一條路由，跑完還原 ---
    before(:all) do
    Rails.application.routes.draw do
        # search
        get "search" => "search#index", as: :search

        # navbar links used by the view
        get "mainpage" => "main#index",      as: :mainpage
        get "scan"     => "scan#index",      as: :scan
        get "profile"  => "profiles#show",   as: :profile

        # form to add queue items (only need path helper)
        resources :queue_items, only: [:create]
    end
    end

    after(:all) do
    Rails.application.reload_routes!
    end

  # --------------------------------------------------------------------

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe "GET #index (JSON)" do
    it "returns [] when q is missing" do
      get :index, format: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it "searches case-insensitively by title or artist and limits to 10" do
      Song.create!(title: "Love Story", artist: "Taylor Swift")
      Song.create!(title: "Crazy in Love", artist: "Beyoncé")
      Song.create!(title: "Lovely Day", artist: "Bill Withers")
      Song.create!(title: "Yellow", artist: "Coldplay") # 不應命中
      12.times { |i| Song.create!(title: "Love ##{i}", artist: "Someone") }

      get :index, params: { q: "LoVe" }, format: :json
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(10) # limit(10)

      titles = json.map { |h| h["title"] }
      expect(titles).to include("Love Story").or include("Crazy in Love").or include("Lovely Day")
      expect(titles).not_to include("Yellow")
    end
  end

  describe "GET #index (HTML)" do
    it "renders 200 and shows the hint text when q is missing" do
      get :index # HTML
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Enter a song title or artist name to search")
    end

    it 'renders a "Search Results" header when q is present' do
      Song.create!(title: "Numb", artist: "Linkin Park")
      get :index, params: { q: "numb" } # HTML
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%{Search Results for "numb"})
    end
  end
end
