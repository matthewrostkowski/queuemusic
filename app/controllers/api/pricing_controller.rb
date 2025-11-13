# app/controllers/api/pricing_controller.rb
module Api
  class PricingController < ApplicationController
    skip_before_action :authenticate_user!
    skip_before_action :verify_authenticity_token  # For API calls
    
    def current_prices
      queue_session = QueueSession.find_by(id: params[:queue_session_id]) || current_queue_session
      
      if queue_session
        positions = (1..10).map do |pos|
          {
            position: pos,
            price_cents: DynamicPricingService.calculate_position_price(queue_session, pos),
            price_display: "$#{'%.2f' % (DynamicPricingService.calculate_position_price(queue_session, pos) / 100.0)}"
          }
        end
        
        render json: { 
          queue_session_id: queue_session.id,
          positions: positions,
          factors: DynamicPricingService.get_pricing_factors(queue_session, nil)
        }
      else
        render json: { error: "No active queue session found" }, status: :not_found
      end
    end
    
    def position_price
      queue_session = QueueSession.find_by(id: params[:queue_session_id]) || current_queue_session
      position = params[:position].to_i
      
      if queue_session && position > 0
        price_cents = DynamicPricingService.calculate_position_price(queue_session, position)
        
        render json: {
          position: position,
          price_cents: price_cents,
          price_display: "$#{'%.2f' % (price_cents / 100.0)}",
          factors: DynamicPricingService.get_pricing_factors(queue_session, position)
        }
      else
        render json: { error: "Invalid queue session or position" }, status: :bad_request
      end
    end
    
    def pricing_factors
      queue_session = QueueSession.find_by(id: params[:queue_session_id]) || current_queue_session
      
      if queue_session
        position = params[:position].to_i
        render json: DynamicPricingService.get_pricing_factors(queue_session, position)
      else
        render json: { error: "No active queue session found" }, status: :not_found
      end
    end
    
  private

  def current_queue_session
    # Get the active queue session or create a default one (same as queues_controller)
    session = QueueSession.active.first || QueueSession.first

    unless session
      # Create a default venue and session if none exist
      venue = Venue.first || Venue.create!(name: "Default Venue")
      session = QueueSession.create!(venue: venue, is_active: true)
    end

    session
  end
  end
end
