require 'test_helper'

class RedirectTest < Capybara::Rails::TestCase
  def setup
    @luke = people :Luke
  end

  test "Follows Redirect" do
    log_in_admin
    visit edit_user_path(@luke.user, referred_by: vacations_path)
    click_on 'Change Language'
    assert_current_path vacations_path
  end

  test "Follows Default in absence of Redirect" do
    log_in_admin
    visit edit_user_path(@luke.user)
    click_on 'Change Language'
    assert_current_path edit_user_path(@luke.user)
  end

  test "Does not use expired redirects" do
    log_in_admin
    visit standard_charge_notes_path
    click_on 'Welcome, Mace' #Stores redirect to standard_charge_notes_path
    visit new_vacation_path
    click_on 'Save'
    assert_current_path vacations_path
    refute page.has_css?('form#new_vacation')
  end
end
