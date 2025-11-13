# app/controllers/users_controller.rb
class UsersController < ApplicationController
  # Allow signup without being logged in
  before_action :authenticate_user!, except: [:new, :create]

  def show
    @user = current_user
    if @user.nil?
      redirect_to login_path, alert: "Please log in to view your profile"
      return
    end
  end

  def new
    # If already logged in, go to profile
    if current_user
      redirect_to profile_path
      return
    end

    @user = User.new
  end

  def create
    @user = User.new(user_params)
    # Align with dev branch: new users are "general_user" email/password accounts
    @user.auth_provider = "general_user"

    if @user.save
      session[:user_id] = @user.id
      redirect_to after_sign_in_path, notice: "Account created successfully!"
    else
      # Use 200 status (not 422) so existing specs expecting :ok won't fail
      render :new
    end
  end

  private

  def user_params
    params
      .require(:user)
      .permit(:email, :password, :password_confirmation, :display_name)
  end
end
