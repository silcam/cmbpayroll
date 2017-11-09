class UsersController < ApplicationController
  before_action :set_user, only: [:edit, :update, :show, :destroy]

  def index
    authorize! :read, User

    @users = User.all
  end

  def new
    authorize! :create, User

    @user = User.new
  end

  def create
    authorize! :create, User

    @user = User.new_with_person(user_params)
    if @user.save
      redirect_to users_path
    else
      render :new
    end
  end

  def edit
    authorize! :update, @user
  end

  def update
    authorize! :update, @user

    if (params[:user][:role])
      authorize! :managerole, User
    end

    if @user.update user_params
      redirect = can?(:read, User) ? users_path : root_path
      follow_redirect redirect, {}
    else
      render :edit
    end
  end

  def destroy
    authorize! :destroy, User

    @user.destroy
    redirect_to users_path
  end

  private

  def user_params
    permitted = [:username, :password, :password_confirmation, :language, :role]
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
