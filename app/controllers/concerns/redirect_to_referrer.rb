module RedirectToReferrer
  extend ActiveSupport::Concern

  included do
    before_action :store_redirect
    send :include, PrivateMethods
  end

  def follow_redirect(default_path, parameters={}, notice=nil)
    if session[:referred_by]
      session[:referred_by_params] = parameters unless parameters.empty?
      redirect_to session[:referred_by], notice: notice
      delete_redirect
    else
      redirect_to default_path
    end
  end

  module PrivateMethods
    private

    def store_redirect
      if params[:referred_by]
        session[:referred_by] = params[:referred_by]
      elsif session[:referred_by]
        manage_stored_redirect
      end
    end

    def manage_stored_redirect
      if session[:referred_to]
        delete_redirect if session[:referred_to] != [controller_name, action_name]
      else
        session[:referred_to] = [controller_name, action_name]
      end
    end

    def delete_redirect
      session.delete :referred_by
      session.delete :referred_to
    end
  end
end
