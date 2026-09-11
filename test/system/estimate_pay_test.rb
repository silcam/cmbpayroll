require 'test_helper'
require "application_system_test_case"

# /admin/estimatepay posts to a .json endpoint over XHR and writes the answer
# into the page. Two independent things must hold, and both were broken:
#
#   1. the form must carry data-remote="true", so UJS intercepts the submit
#      instead of letting the browser navigate to the .json URL. form_with
#      takes local:, not remote:, and silently dropped the option -- harmless
#      until load_defaults 6.1 set form_with_generates_remote_forms = false.
#   2. the ajax:success handler must be bound when the page is reached through
#      a Turbolinks link. admin.coffee used $(document).ready, which does not
#      fire when Turbolinks swaps the body.
#
# One test each, because they fail independently and a combined test cannot say
# which broke. Neither is visible to a controller test: the controller returns
# correct JSON either way.
class EstimatePayTest < ApplicationSystemTestCase
  test "estimating pay answers in the page instead of navigating to the json" do
    log_in_admin

    visit estimate_pay_path
    wait_for_estimate_form

    fill_field 'estimate', '1000000'

    # Submit with Return rather than clicking. A coordinate click on the submit
    # button is the single least reliable interaction in this suite (see
    # NOTES-upgrade.md); pressing Return in the field is an equally real user
    # action, goes through the same UJS submit path, and does not depend on
    # where the button happens to be when the click lands.
    find_field('estimate').send_keys(:return)

    expected = Payslip.compute_wage_from_departmental_charge(1_000_000)
    assert_selector '#estimate-response', text: expected.to_s

    # The browser must still be on the HTML page. Without data-remote the
    # submit navigates to /admin/estimate.json and the user reads raw JSON.
    assert_current_path estimate_pay_path
  end

  test "the ajax handler is bound when the page is reached through a link" do
    log_in_admin

    # Through the admin index, the way a user gets here -- Turbolinks
    # intercepts this link, so $(document).ready never fires. Visiting the URL
    # directly would hide exactly the bug this covers.
    visit admin_index_path
    click_link 'Estimate Pay'

    assert_current_path estimate_pay_path
    wait_for_estimate_form
  end
end
