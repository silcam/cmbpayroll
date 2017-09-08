require 'test_helper'

class LoginTest < Capybara::Rails::TestCase
  def setup
    @luke = employees :Luke
  end

  test "valid user logs in" do
    visit root_path
    login_form('luke', 'luke')
    assert page.has_content?(@luke.first_name), "Expect to see user's first name"
    click_link('Log out')
    assert_current_path login_path
  end

  test "invalid logins" do
    visit root_path
    login_form('', 'blah')
    assert_login_invalid

    login_form('luke', 'blahblahblah')
    assert_login_invalid
  end

  test "login redirect" do
    visit employees_path
    assert_current_path login_path
    login_form('luke', 'luke')
    assert_current_path employees_path
  end

  def login_form(username, password)
    fill_in 'Username', with: username
    fill_in 'Password', with: password
    click_button 'Log in'
  end

  def assert_login_invalid
    assert_current_path login_path
    assert page.has_content?('Sorry, the username or password is incorrect')
  end
end
