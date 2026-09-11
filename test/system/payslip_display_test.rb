require 'test_helper'
require "application_system_test_case"

# Renders a real, processed payslip in a real browser.
#
# The unit suite checks that Payslip.process computes the right numbers, and
# the integration suite checks that the controller responds -- but neither
# renders show.html.erb through a browser, so a view that binds the wrong
# attribute into a row, or a helper that stops resolving, passes both. That is
# the gap this closes, and it is the gap that matters most for a Rails upgrade:
# number_to_currency with a custom :cm locale and the Employee.categories
# .invert lookups are exactly the kind of thing a version bump breaks quietly.
#
# Deliberately GET-only. There is no form to submit and no JS on this page, so
# it avoids both flakiness mechanisms documented in NOTES-upgrade.md.
class PayslipDisplayTest < ApplicationSystemTestCase
  def setup
    @employee = return_valid_employee
    @payslip = create_and_return_payslip(@employee)
  end

  test "payslip page renders the processed figures" do
    log_in_admin
    visit payslip_path(@payslip)

    assert_text @employee.full_name
    assert_text @payslip.id.to_s

    # Assert against the rendered row, not the whole page: the same figure can
    # legitimately appear elsewhere, so matching document-wide would still pass
    # if the Base Wage cell were bound to the wrong attribute.
    assert_selector 'table.payslip', text: currency(@payslip.basewage)
    assert_selector 'table.payslip', text: currency(@payslip.wage)
  end

  private

  def currency(amount)
    ActionController::Base.helpers.number_to_currency(amount, locale: :cm)
  end
end
