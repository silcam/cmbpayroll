class UsersController < ApplicationController
  # TODO !!!!!!! Remove this once we have users created everywhere
  skip_before_action :require_login, only: [:new, :create]

  before_action :set_user, only: [:edit, :update, :show, :destroy]

  def index
    @users = User.all
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new_with_person(user_params)
    if @user.save
      redirect_to users_path
    else
      render :new
    end
  end

  def edit

  end

  def update
    if @user.update user_params
      follow_redirect users_path
    else
      render :edit
    end
  end

  def destroy
    @user.destroy
    redirect_to users_path
  end

  private

  def user_params
    permitted = [:username, :password, :password_confirmation, :language]
    if params[:new_person]=='true'
      permitted += [:first_name, :last_name]
    else
      permitted << :person_id
    end
    params.require(:user).permit(permitted)
  end

  def set_user
    @user = User.find params[:id]
  end
end
