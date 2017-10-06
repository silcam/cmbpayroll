class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  include SessionsHelper
  include RedirectToReferrer

  before_action :require_login, :set_locale

  private

  def require_login
    return if logged_in?

    session[:original_request] = request.path
    redirect_to login_path
  end

  def set_locale
    I18n.locale = current_user.try(:language) || I18n.default_locale
  end

  #TODO set not_allowed_path
  rescue_from "AccessGranted::AccessDenied" do |exception|
    redirect_to not_allowed_path
  end

  def get_params_period(default=Period.current)
    params[:period] ? Period.fr_str(params[:period]) : default
  end
end
