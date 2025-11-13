require 'rails_helper'

RSpec.describe SongsController, type: :controller do
  let(:user) { create(:user) }
  before { login_as(user) }

  describe 'GET #search' do
    let(:deezer_results) do
      [
        {
          spotify_id: '123',
          title: 'Test Song',
          artist: 'Test Artist',
          cover_url: 'http://example.com/cover.jpg',
          duration_ms: 200000,
          preview_url: 'http://example.com/preview.mp3'
        }
      ]
    end

    context 'with a valid query' do
      before do
        allow_any_instance_of(SongsController).to receive(:search_deezer).with('test').and_return(deezer_results)
      end

      it 'returns a successful HTML response' do
        get :search, params: { q: 'test' }
        expect(response).to be_successful
        expect(assigns(:results)).to eq(deezer_results)
      end

      it 'returns a successful JSON response' do
        get :search, params: { q: 'test' }, format: :json
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response['results']).to eq(deezer_results.map(&:deep_stringify_keys))
      end
    end

    context 'with an empty query' do
      it 'returns a successful HTML response with no results' do
        get :search, params: { q: '' }
        expect(response).to be_successful
        expect(assigns(:results)).to eq([])
      end

      it 'returns a successful JSON response with no results' do
        get :search, params: { q: '' }, format: :json
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response['results']).to eq([])
      end
    end

    context 'when Deezer search fails' do
      before do
        allow_any_instance_of(SongsController).to receive(:search_deezer).with('fail').and_return([])
      end

      it 'returns a successful HTML response with no results' do
        get :search, params: { q: 'fail' }
        expect(response).to be_successful
        expect(assigns(:results)).to eq([])
      end

      it 'returns a successful JSON response with no results' do
        get :search, params: { q: 'fail' }, format: :json
        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response['results']).to eq([])
      end
    end
  end
end
