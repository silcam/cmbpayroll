class HomeController < ApplicationController

  def home
    if current_user.admin?
      @alerts = Alert.get_all
    end
  end

end
