require 'test_helper'
require "application_system_test_case"

# Exercises AccessPolicy end to end through a browser.
#
# The integration suite already checks permissions per route, but it stops at
# the response. This covers the part only a rendered page shows: that
# ApplicationController's rescue_from AccessGranted::AccessDenied actually
# redirects, and that the resulting flash reaches the layout and is visible to
# the user rather than being swallowed. rescue_from and flash rendering are
# both places a Rails upgrade can change behaviour quietly.
#
# GET-only by design -- no forms and no page JS, so neither of the flakiness
# mechanisms in NOTES-upgrade.md applies.
class AuthorizationTest < ApplicationSystemTestCase
  def setup
    @jarjar = users :JarJar
    @luke = employees :Luke
  end

  test "a plain user is bounced from another employee's record" do
    log_in @jarjar

    visit employee_path(@luke)

    assert_current_path root_path
    assert_selector 'p#permissions-error'
  end

  test "an admin reaches the same record" do
    log_in_admin

    visit employee_path(@luke)

    assert_current_path employee_path(@luke)
    refute_selector 'p#permissions-error'
  end
end
