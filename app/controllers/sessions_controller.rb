class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    user = User.find_by(username: params['username']).try(:authenticate, params['password'])
    if user
      log_in user
      send_to_correct_page
    else
      @failed_login = true
      render :new
    end
  end

  def destroy
    log_out
    redirect_to root_path
  end

  private

  def send_to_correct_page
    if session[:original_request]
      redirect_to session[:original_request]
      session.delete(:original_request)
    else
      redirect_to root_path
    end
  end
end
