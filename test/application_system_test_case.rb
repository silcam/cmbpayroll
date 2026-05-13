require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  def log_in(user)
    visit login_path
    fill_in 'Username', with: user.username
    fill_in 'Password', with: user.username
    click_button 'Log in'
  end

  def log_in_luke
    log_in users(:Luke)
  end

  def log_in_admin
    visit login_path
    fill_in 'Username', with: 'mace'
    fill_in 'Password', with: 'mace'
    click_button 'Log in'
  end
end
