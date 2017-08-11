module SessionsHelper
  def log_in(person)
    session[:user_id] = person.id
  end

  def current_user
    @current_user ||= Employee.find_by id: session[:user_id]
  end

  def logged_in?
    !current_user.nil?
  end

  def log_out
    session.delete(:user_id)
    @current_user = nil
  end
end
