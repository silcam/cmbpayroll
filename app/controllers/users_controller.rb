class UsersController < ApplicationController

  before_action :set_user, only: [:edit, :update, :show, :destroy]

  def index
    @users = User.all
  end

  def new
    @user = User.new_with_person
  end

  def create
    @user = User.new_with_person(user_params)
    if @user.save
      redirect_to users_path
    else
      render :new
    end
  end

  private

  def user_params
    permitted = [:username, :password, :password_confirmation]
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
