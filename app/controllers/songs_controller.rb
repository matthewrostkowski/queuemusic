# app/controllers/songs_controller.rb
require_relative '../services/dynamic_pricing_service'

class SongsController < ApplicationController
  require 'net/http'
  require 'json'

  before_action :authenticate_user!

  def search
    @query = params[:q]

    respond_to do |format|
      format.html do
        @results = []
        if @query.present?
          @results = search_deezer(@query)
        end
      end
      format.json do
        if @query.present?
          # Search using Deezer API (same as HTML format)
          results = search_deezer(@query)
          render json: { results: results }
        else
          render json: { results: [] }
        end
      end
    end
  end

  def index
    @songs = Song.all
  end

  def show
    @song = Song.find(params[:id])
  end

  def price_preview
    queue_session = current_queue_session
    desired_position = params[:position]&.to_i || queue_session&.songs_count.to_i + 1

    if params[:position] == 'next' || desired_position == 0
      desired_position = queue_session ? queue_session.songs_count + 1 : 1
    elsif params[:position] == 'next_plus_1'
      desired_position = queue_session ? queue_session.songs_count + 2 : 2
    elsif params[:position] == 'next_plus_2'
      desired_position = queue_session ? queue_session.songs_count + 3 : 3
    end

    price_cents = DynamicPricingService.calculate_position_price(queue_session, desired_position)

    render json: {
      position:       desired_position,
      price_cents:    price_cents,
      price_display:  "$#{'%.2f' % (price_cents / 100.0)}",
      factors:        DynamicPricingService.get_pricing_factors(queue_session, desired_position)
    }
  end

  private

  def search_deezer(query)
    uri = URI("https://api.deezer.com/search")
    uri.query = URI.encode_www_form({ q: query, limit: 20 })

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?

    request  = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    if response.code == "200"
      data   = JSON.parse(response.body)
      tracks = data["data"] || []

      tracks.map do |track|
        {
          spotify_id:  track["id"].to_s,
          title:       track["title"],
          artist:      track.dig("artist", "name"),
          cover_url:   track.dig("album", "cover_medium") || track.dig("album", "cover_big"),
          duration_ms: (track["duration"] * 1000).to_i,
          preview_url: track["preview"]
        }
      end
    else
      Rails.logger.error("Deezer search failed: #{response.code} - #{response.body}")
      []
    end
  rescue => e
    Rails.logger.error("Deezer search error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    []
  end
end
