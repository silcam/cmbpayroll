require 'test_helper'
require "application_system_test_case"

# Walks the payslip path a user actually has: employee page -> payroll history
# -> reprocess.
#
# Deliberately does NOT render payslips/show.html.erb. That template exists but
# is effectively dead -- every link in the app passes format: :pdf, and
# PayslipsController#process_employee_complete redirects to the PDF too, so the
# HTML branch is reachable only by hand-editing a URL. Testing it would have
# kept a debug view on life support and proved nothing about what users see.
# The rendered figures live in the PDF, and test/models/payslip_pdf_test.rb
# already covers that.
#
# What is left for a browser to prove is the navigation and the reprocess POST,
# which nothing else exercises end to end.
class PayslipHistoryTest < ApplicationSystemTestCase
  def setup
    @employee = return_valid_employee
    @payslip = create_and_return_payslip(@employee)
  end

  test "an employee's payroll history lists the processed period" do
    log_in_admin

    visit employee_payslips_path(@employee)

    assert_text @employee.full_name
    assert_text @payslip.period.l_name

    # The link must carry format: :pdf -- the HTML branch of payslips#show is
    # not a page anyone is meant to land on.
    assert_selector "a[href='#{payslip_path(@payslip, format: :pdf)}']"
  end

  test "reprocessing from the history page shows the hours summary" do
    log_in_admin

    visit employee_payslips_path(@employee)
    click_button 'employee-reprocess'

    # process_employee renders the hours it computed for the period rather than
    # redirecting, so this covers the POST, the controller and the view.
    assert_text @employee.full_name
    assert_text WorkHour.total_hours(@employee, LastPostedPeriod.current)[:normal].to_s
  end
end
