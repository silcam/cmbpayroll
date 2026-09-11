require 'test_helper'
require "application_system_test_case"

# Submits a real multi-attribute form through a real browser.
#
# Nothing else in the system suite posts a form with model-nested attributes.
# That is the single biggest coverage gap for a Rails upgrade: strong
# parameters, form_for's url/method overrides and the date_select multi-
# parameter attributes (birth_date(1i), (2i), (3i)) are all version-sensitive,
# and all of them are invisible to a controller test that hand-builds its
# params hash.
#
# Uses the :personal page on purpose. employees.coffee animates the wage and
# supervisor fields with jQuery show('fast')/hide('fast') on turbolinks:load,
# which moves everything below them mid-animation -- the same moving-target
# problem that makes the vacation form flaky, only worse. Neither
# input[data-wage] nor select#employee_supervisor_id is rendered by
# _personal_form, so those handlers match nothing and no animation runs.
class EmployeeFormTest < ApplicationSystemTestCase
  def setup
    @employee = employees :Luke
  end

  test "edits an employee's personal details through the form" do
    log_in_admin

    visit edit_employee_path(@employee, page: :personal)
    assert_selector "input#employee_first_name"

    # fill_field (not fill_in) so a silently-dropped keystroke fails here
    # rather than at the assertion after the submit. The submit is addressed by
    # type, not by its "Save" text, to stay locale-independent.
    fill_field 'employee_first_name', 'Lucas'
    fill_field 'employee_last_name', 'Starkiller'
    click_button 'Save'

    assert_current_path employee_path(@employee)
    assert_text 'Lucas'
    assert_text 'Starkiller'

    # Through the browser the round trip has to survive strong params, so
    # confirm it actually persisted rather than only that the page says so.
    @employee.reload
    assert_equal 'Lucas', @employee.first_name
    assert_equal 'Starkiller', @employee.last_name
  end

  test "re-renders the form with errors when a required field is blanked" do
    log_in_admin

    visit edit_employee_path(@employee, page: :personal)
    assert_selector "input#employee_first_name"

    fill_field 'employee_last_name', ''
    find("input[type='submit']").click

    # Assert the error partial specifically, not just "still on the form".
    # A dropped click -- the failure mode documented in NOTES-upgrade.md --
    # also leaves the browser on the form, so a bare still-on-the-form check
    # would pass without the invalid branch ever running.
    assert_selector 'div.error-explanation li'
    refute_equal '', @employee.reload.last_name
  end
end
