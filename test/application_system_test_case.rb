require "test_helper"

# Headroom for a real browser on a loaded machine. Capybara's 2s default is
# tuned for an in-process driver; here every wait is a round trip to Chrome,
# and the dropped-interaction problem documented below is strongly
# load-sensitive.
#
# An earlier comment justified this by on-demand asset compilation and called
# it "measured: no improvement". Both are withdrawn: the asset-cache theory is
# in NOTES-upgrade.md's falsified list, and the figure was measured while the
# suite was still forking four workers, so it says nothing about the serial
# suite this is now tuned for.
Capybara.default_max_wait_time = 10

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  # Run system tests serially, even though test_helper.rb parallelizes.
  #
  # parallelize(workers: :number_of_processors) is declared on
  # ActiveSupport::TestCase, and ActionDispatch::SystemTestCase inherits from
  # it -- so this suite was forking four workers, each booting its own Puma AND
  # its own headless Chrome. Rails 6.1 has no test_parallelization_threshold
  # (that arrived in 7.0), so the small suite size does not save us. The result
  # was resource starvation, not a race: logins timed out after ~20s waiting
  # for a page to render.
  #
  #   parallel (4 workers) -- 2 to 4 failures every run, never green
  #   serial               -- 3 of 5 runs green, rising to 6 of 6 once the
  #                           synchronisation points below were added
  #
  # This matters for CI as much as for a dev box: GitHub's ubuntu-latest
  # runners are 2-4 cores, so they would have thrashed the same way.
  #
  # BOTH overrides are required. parallelize_me! mixes in
  # Minitest::Parallel::Test::ClassMethods, which defines test_order (used to
  # partition suites) AND run_one_method (which pushes onto the executor).
  # Overriding only test_order puts the suite in the serial partition and then
  # hands every test to the workers anyway -- measured: a 3-test file still
  # booted 3 Pumas. A singleton method here takes precedence over the extended
  # module. Unit tests are untouched and still parallelize.
  def self.test_order
    :random
  end

  # Delegates to Minitest::Runnable's own implementation rather than copying
  # its two lines, so this stays correct if minitest changes them.
  def self.run_one_method(klass, method_name, reporter)
    Minitest::Runnable.singleton_class
                      .instance_method(:run_one_method)
                      .bind_call(self, klass, method_name, reporter)
  end

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
  # English. Measured 6/10 passing on text against 18/22 on the href -- both
  # taken before system tests were made serial, so treat the ratios as a
  # comparison between the two, not as the current pass rate. The reason to
  # match the href does not depend on them.
  def wait_for_login
    assert_selector "a[href='#{logout_path}']"
  end

  # fill_in occasionally lands on the element and then silently fails to change
  # its value -- measured directly by reading the value back through JS
  # immediately after the call. When that happens the test does not fail at the
  # fill; it fails ten seconds later at whatever assertion follows the submit,
  # pointing at the wrong line. Asserting the value here moves the failure to
  # the statement that actually went wrong.
  #
  # Takes a field id rather than label text on purpose: set_locale renders
  # every label in current_user.language, so matching visible text makes a test
  # locale-dependent -- the same trap wait_for_login documents above.
  #
  # Compares the element's own value rather than using assert_field(with:),
  # which does not match a field that was deliberately blanked.
  def fill_field(id, value)
    fill_in id, with: value
    assert_equal value.to_s, find_field(id).value.to_s,
                 "fill_in on ##{id} did not change the field"
  end

  # Waits until admin.coffee's turbolinks:load handler has actually bound its
  # ajax:success listener, which is the precondition EstimatePayTest is about.
  # The form element exists before the handler is attached, so asserting on the
  # form alone lets the test act on a page that is not yet wired up.
  def wait_for_estimate_form
    assert_selector '#estimate-form'
    assert page.document.synchronize(Capybara.default_max_wait_time, errors: [RuntimeError]) {
      bound = page.evaluate_script(
        "!!(window.jQuery && jQuery._data(document.getElementById('estimate-form'), 'events'))"
      )
      raise 'estimate-form handlers not bound yet' unless bound
      true
    }
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
