require 'test_helper'
require "application_system_test_case"

class RedirectTest < ApplicationSystemTestCase
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
    assert_current_path users_path
  end

  # Skipped deliberately -- see NOTES-upgrade.md, "RedirectToReferrer needs
  # rewriting". This test pins the CURRENT expiry semantics, which we have
  # decided are the wrong ones: store_redirect keeps a stored redirect alive
  # for exactly one controller/action pair, so any single intervening request
  # between loading a form and submitting it silently discards the redirect.
  # The intended fix is to have follow_redirect prefer params[:referred_by]
  # (the pattern VacationsController already uses via a hidden field) and
  # treat the session as a fallback. When that lands, this test should be
  # rewritten to assert the new behaviour rather than un-skipped as-is.
  #
  # It is also the least stable of the eight: it drives the vacation form,
  # whose AJAX-on-turbolinks:load rewrites the DOM under the Save button.
  # Measured 2 failures in 12 serial runs -- the worst of any single test.
  test "Does not use expired redirects" do
    skip "Pins redirect-expiry semantics we intend to replace -- see NOTES-upgrade.md"

    log_in_admin
    visit standard_charge_notes_path
    click_on 'Welcome, Mace' #Stores redirect to standard_charge_notes_path
    visit new_vacation_path
    wait_for_vacation_form
    click_on 'Save'
    assert_current_path vacations_path
    refute page.has_css?('form#new_vacation')
  end
end
