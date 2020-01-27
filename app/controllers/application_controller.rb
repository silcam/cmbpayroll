class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  include SessionsHelper
  include RedirectToReferrer

  NUMBER_OF_MONTHS_SHOWN=24

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

  rescue_from "AccessGranted::AccessDenied" do |exception|
    redirect_to root_path, alert: "You cannot perform this action."
  end

  def get_params_period(default=Period.current)
    params[:period] ? Period.fr_str(params[:period]) : default
  end

  def get_periods_list()
    periods_list = {}

    starting_period = nil
    if (Rails.configuration.try(:starting_period))
      starting_period = Period.fr_str(Rails.configuration.starting_period)
    end

    period = Period.current()

    (0..NUMBER_OF_MONTHS_SHOWN).each do |x|
      periods_list[period.name] = period.to_s
      period = period.previous
      break if starting_period && period < starting_period
    end

    return periods_list
  end

end
