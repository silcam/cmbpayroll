class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  include SessionsHelper

  before_action :require_login, :set_locale, :store_redirect

  def follow_redirect default_path, parameters={}
    if session[:referred_by]
      session[:referred_by_params] = parameters unless parameters.empty?
      redirect_to session[:referred_by]
      session.delete :referred_by
    else
      redirect_to default_path
    end
  end

  private

  def require_login
    return if logged_in?

    session[:original_request] = request.path
    redirect_to login_path
  end

  def set_locale
    I18n.locale = current_user.try(:language) || I18n.default_locale
  end

  def store_redirect
    session[:referred_by] = params[:referred_by] if params[:referred_by]
  end

  #TODO set not_allowed_path
  rescue_from "AccessGranted::AccessDenied" do |exception|
    redirect_to not_allowed_path
  end

  def get_params_period
    params[:period] ? Period.fr_str(params[:period]) : Period.current
  end
end
