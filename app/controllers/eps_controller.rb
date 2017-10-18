class EPSController < ApplicationController

  rescue_from "AccessGranted::AccessDenied" do |exception|
    redirect_to root_path, alert: "You cannot perform this action."
  end

end
