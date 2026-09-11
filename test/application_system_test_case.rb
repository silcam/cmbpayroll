require "test_helper"

# The first page load in a process pays for on-demand asset compilation, which
# can exceed Capybara's 2s default on a loaded machine. On its own this changes
# nothing (measured: no improvement), but combined with the explicit
# synchronisation points below it matters -- see NOTES-upgrade.md.
Capybara.default_max_wait_time = 10

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  def log_in(user)
    visit login_path
    fill_in 'Username', with: user.username
    fill_in 'Password', with: user.username
    click_button 'Log in'
    wait_for_login
  end

  def log_in_luke
    log_in users(:Luke)
  end

  def log_in_admin
    visit login_path
    fill_in 'Username', with: 'mace'
    fill_in 'Password', with: 'mace'
    click_button 'Log in'
    wait_for_login
  end

  # A synchronisation point, not an assertion about logging out.
  #
  # click_button returns as soon as the click is dispatched, not when the
  # resulting request completes. Without this wait the next statement runs
  # while the browser is still mid-navigation, and requests were observed
  # arriving out of order -- a `visit` landing BEFORE the login POST it was
  # supposed to follow. That matters here because RedirectToReferrer's
  # store_redirect runs on every request and drops session[:referred_by] as
  # soon as one hits a different controller/action, so a stray out-of-order
  # request silently sends the assertion to the wrong page.
  #
  # Match on the logout link's href rather than its text: set_locale runs on
  # every request off current_user.language, and RedirectTest submits a form
  # that CHANGES a user's language, so the rendered text is not reliably
  # English. Matching text: 'Log out' measured 6/10 passing; matching the href
  # measured 18/22.
  def wait_for_login
    assert_selector "a[href='#{logout_path}']"
  end

  # vacations.coffee clears #days-summary to '<br>' on turbolinks:load, fires
  # an AJAX request for the balance, and only then fills the div back in.
  # Acting on the form during that window races with the DOM being rewritten
  # underneath us and the submit is silently dropped -- the server never
  # receives POST /vacations at all (confirmed by logging every request).
  def wait_for_vacation_form
    assert_selector '#days-summary li'
  end
end
