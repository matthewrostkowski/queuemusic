require 'rails_helper'

RSpec.describe Admin::BalanceTransactionsController, type: :controller do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  describe 'before_actions' do
    context 'when not authenticated' do
      it 'redirects to the login page' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated as a non-admin user' do
      before { sign_in user }

      it 'redirects to the root path with an alert' do
        get :index
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('You must be an admin to access this page')
      end
    end
  end

  context 'when authenticated as an admin' do
    before { sign_in admin }

    describe 'GET #index' do
      it 'returns a successful response and assigns variables' do
        get :index
        expect(response).to be_successful
        expect(assigns(:users)).to be_a(ActiveRecord::Relation)
        expect(assigns(:recent_transactions)).to be_a(ActiveRecord::Relation)
      end
    end

    describe 'GET #show' do
      it 'returns a successful response and assigns variables' do
        get :show, params: { id: user.id }
        expect(response).to be_successful
        expect(assigns(:user)).to eq(user)
        expect(assigns(:transactions)).to be_a(ActiveRecord::Relation)
      end
    end

    describe 'POST #add_credit' do
      context 'with a valid amount' do
        it "adds credit to the user's balance and redirects" do
          post :add_credit, params: { id: user.id, amount_cents: 1000 }
          expect(user.reload.balance_cents).to eq(1000)
          expect(response).to redirect_to(admin_balance_transactions_path)
          expect(flash[:notice]).to include("Added $10.00 to #{user.display_name}'s balance")
        end
      end

      context 'with an invalid amount' do
        it 'does not add credit and redirects with an alert' do
          post :add_credit, params: { id: user.id, amount_cents: 0 }
          expect(user.reload.balance_cents).to eq(0)
          expect(response).to redirect_to(admin_balance_transactions_path)
          expect(flash[:alert]).to eq('Invalid amount')
        end
      end
    end
  end
end