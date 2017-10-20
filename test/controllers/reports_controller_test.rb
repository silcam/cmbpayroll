require "test_helper"

class ReportsControllerTests < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  def test_reports_hash
    @reports = ReportsController::REPORTS
    first_key = @reports.keys.first

    assert(@reports[first_key][:name].is_a?(String))
    assert(@reports[first_key][:instance].is_a?(Proc))
  end

  # user

  test "Reports : USER"  do
    login_user(:Luke)

    refute_user_permission(reports_url(), "get") # reports#index
    refute_user_permission(report_display_url(), "get") # reports#show

    get dossier_report_url("employee_by_department") # dossier/reports#show
    assert_response :success
    assert_select "h2#home", "Tasks"

    get dossier_multi_report_url("employee_by_department") # dossier/reports#multi
    assert_response :success
    assert_select "h2#home", "Tasks"
  end

  test "User: can't see add link on home" do
    login_user(:Luke)
    get root_url()

    assert_select "a#reports-link", false
  end

  # supervisor

  test "Reports : Supervisor"  do
    login_supervisor(:Quigon)

    refute_user_permission(reports_url(), "get") # reports#index
    refute_user_permission(report_display_url(), "get") # reports#show

    get dossier_report_url("employee_by_department") # dossier/reports#show
    assert_response :success
    assert_select "h2#home", "Tasks"

    get dossier_multi_report_url("employee_by_department") # dossier/reports#multi
    assert_response :success
    assert_select "h2#home", "Tasks"
  end

  test "Supervisor: can't see add link on home" do
    login_supervisor(:Quigon)
    get root_url()

    assert_select "a#reports-link", false
  end

  # admin

  test "Reports : Admin"  do
    login_admin(:MaceWindu)

    assert_user_permission(reports_url(), "get") # reports#index
    assert_user_permission(report_display_url(), "get") # reports#show

    get dossier_report_url("employee_by_department") # dossier/reports#show
    assert_response :success
    assert_select "h2#home", "Tasks"

    get dossier_multi_report_url("employee_by_department") # dossier/reports#multi
    assert_response :success
    assert_select "h2#home", "Tasks"
  end

  test "Admin: can't see add link on home" do
    login_admin(:MaceWindu)
    get root_url()

    assert_select "a#reports-link"
  end
end
