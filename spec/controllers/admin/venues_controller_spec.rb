# spec/controllers/admin/venues_controller_spec.rb
require "rails_helper"

RSpec.describe Admin::VenuesController, type: :controller do
  routes { Rails.application.routes }

  let(:user) { instance_double(User, id: 1) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe "access control" do
    context "when user is NOT admin" do
      before { allow(user).to receive(:admin?).and_return(false) }

      it "redirects to root_path with alert on index" do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You must be an admin to access this page")
      end
    end

    context "when user IS admin" do
      before { allow(user).to receive(:admin?).and_return(true) }

      it "allows access to index" do
        # stub：Venue.all.order(:name)
        rel = instance_double("ActiveRecord::Relation")
        allow(Venue).to receive(:all).and_return(rel)
        allow(rel).to receive(:order).with(:name).and_return([])

        allow(controller).to receive(:render).and_return(nil)

        get :index
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "CRUD as admin" do
    before { allow(user).to receive(:admin?).and_return(true) }

    let(:venue_double) do
      instance_double(
        Venue,
        id: 42,
        name: "Test Venue",
        location: "Somewhere",
        capacity: 100,
        queue_sessions: queue_sessions_double
      )
    end

    let(:queue_sessions_double) do
      active_scope = instance_double("ActiveScope")
      allow(active_scope).to receive(:to_a).and_return([])
      allow(active_scope).to receive(:count).and_return(0)

      qs = instance_double("QueueSessionsAssoc")
      allow(qs).to receive(:active).and_return(active_scope)
      allow(qs).to receive(:count).and_return(0)
      qs
    end

    it "GET #show renders ok (stubbing render)" do
      allow(Venue).to receive(:find).with("42").and_return(venue_double)
      allow(controller).to receive(:render).and_return(nil)

      get :show, params: { id: "42" }
      expect(response).to have_http_status(:ok)
    end

    it "GET #new renders ok (stubbing render)" do
      allow(Venue).to receive(:new).and_return(venue_double)
      allow(controller).to receive(:render).and_return(nil)

      get :new
      expect(response).to have_http_status(:ok)
    end

    it "POST #create redirects to index on success" do
      expect(Venue).to receive(:new).with(hash_including("name" => "A", "location" => "L", "capacity" => "200"))
                                    .and_return(venue_double)
      allow(venue_double).to receive(:save).and_return(true)

      post :create, params: { venue: { name: "A", location: "L", capacity: 200, ignored: "x" } }
      expect(response).to redirect_to(admin_venues_path)
      expect(flash[:notice]).to eq("Venue was successfully created.")
    end

    it "GET #edit renders ok (stubbing render)" do
      allow(Venue).to receive(:find).with("42").and_return(venue_double)
      allow(controller).to receive(:render).and_return(nil)

      get :edit, params: { id: "42" }
      expect(response).to have_http_status(:ok)
    end

    it "PATCH #update redirects to index on success" do
      allow(Venue).to receive(:find).with("42").and_return(venue_double)
      expect(venue_double).to receive(:update).with(hash_including("name" => "B", "location" => "NYC", "capacity" => "300")).and_return(true)

      patch :update, params: { id: "42", venue: { name: "B", location: "NYC", capacity: 300 } }
      expect(response).to redirect_to(admin_venues_path)
      expect(flash[:notice]).to eq("Venue was successfully updated.")
    end

    it "PATCH #update_pricing redirects to edit on success" do
      allow(Venue).to receive(:find).with("42").and_return(venue_double)

      expect(venue_double).to receive(:update).with(hash_including(
        "pricing_enabled" => "1",
        "base_price_cents" => "200",
        "min_price_cents" => "100",
        "max_price_cents" => "500",
        "price_multiplier" => "1.2",
        "peak_hours_start" => "18:00",
        "peak_hours_end" => "22:00",
        "peak_hours_multiplier" => "1.5"
      )).and_return(true)

      patch :update_pricing, params: {
        id: "42",
        venue: {
          pricing_enabled: 1,
          base_price_cents: 200,
          min_price_cents: 100,
          max_price_cents: 500,
          price_multiplier: 1.2,
          peak_hours_start: "18:00",
          peak_hours_end: "22:00",
          peak_hours_multiplier: 1.5
        }
      }

      expect(response).to redirect_to(edit_admin_venue_path(venue_double))
      expect(flash[:notice]).to eq("Pricing settings updated successfully.")
    end
  end
end
