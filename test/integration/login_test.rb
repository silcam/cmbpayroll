require 'test_helper'

class LoginTest < Capybara::Rails::TestCase
  def setup
    @luke = employees :Luke
  end

  test "valid user logs in" do
    visit root_path
    click_button 'Log in'
    assert page.has_content?(@luke.first_name), "Expect to see user's first name"
    click_link('Log out')
    assert_current_path login_path
  end

  test "invalid log in" do
    # TODO
  end

  test "login redirect" do
    visit employees_path
    assert_current_path login_path
    click_button 'Log in'
    assert_current_path employees_path
  end
end
