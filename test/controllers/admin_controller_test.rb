require "test_helper"

class AdminControllerControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  #### ESTIMATE PAY ####

  # Regression guard for a 6.1 upgrade break. The estimate form posts to a
  # .json endpoint over XHR; without data-remote="true" the browser navigates
  # to that URL and shows the user raw JSON.
  #
  # form_with takes local:, not remote:, and silently drops an unrecognised
  # remote: option. That was harmless while form_with was remote by default,
  # but load_defaults 6.1 sets form_with_generates_remote_forms = false, so the
  # form rendered with no data-remote at all.
  #
  # Asserted here rather than only in a system test because it is a property of
  # the rendered markup, so it can be checked deterministically -- the system
  # test that drives the same form is subject to the dropped-interaction
  # artifact documented in NOTES-upgrade.md.
  test "ADMIN: estimate pay form is a remote form" do
    login_admin(:MaceWindu)

    get estimate_pay_url

    assert_response :success
    assert_select "form#estimate-form[data-remote=?]", "true"
  end

  test "ADMIN: estimate pay posts json" do
    login_admin(:MaceWindu)

    post "#{estimate_pay_post_path}.json", params: { estimate: 1_000_000 }

    assert_response :success
    assert_equal Payslip.compute_wage_from_departmental_charge(1_000_000),
                 JSON.parse(response.body)
  end

  #### USER ####

  test "Admin Pages : User" do
    login_user(:Luke)
    refute_user_permission(admin_index_url(), "get") # index
    refute_user_permission(admin_manage_variables_url(), "get") # system vars

    wage = Wage.all.first

    refute_user_permission(admin_manage_wages_url(), "get") # manage_wages
    refute_user_permission(admin_manage_wage_show_url(wage), "get") # manage_wage
    refute_user_permission(admin_manage_wage_show_url(wage), "post", params: {
        wage: { :basewage => 123, :basewageb => 123, :basewagec => 123,
          :basewaged => 123, :basewagee => 123 }}) # manage_wage_update
  end

  test "USER: can admin link on home#home" do
    login_user(:Luke)
    get root_url()
    assert_select "a#admin-link", false
  end

  #### Supervisor ####

  test "Admin Pages : Supervisor" do
    login_supervisor(:Quigon)
    refute_supervisor_permission(admin_index_url(), "get") # index
    refute_supervisor_permission(admin_manage_variables_url(), "get") # system vars

    wage = Wage.all.first

    refute_supervisor_permission(admin_manage_wages_url(), "get") # manage_wages
    refute_supervisor_permission(admin_manage_wage_show_url(wage), "get") # manage_wage
    refute_supervisor_permission(admin_manage_wage_show_url(wage), "post", params: {
        wage: { :basewage => 123, :basewageb => 123, :basewagec => 123,
          :basewaged => 123, :basewagee => 123 }}) # manage_wage_update
  end

  test "Supervisor: can admin link on home#home" do
    login_supervisor(:Quigon)
    get root_url()
    assert_select "a#admin-link", false
  end

  #### Admin ####

  test "Admin Pages : Admin" do
    login_admin(:MaceWindu)
    assert_admin_permission(admin_index_url(), "get") # index
    assert_supervisor_permission(admin_manage_variables_url(), "get") # system vars

    wage = Wage.all.first

    assert_admin_permission(admin_manage_wages_url(), "get") # manage_wages
    assert_admin_permission(admin_manage_wage_show_url(category: wage.category,
        echelon: wage.echelon, echelonalt: wage.echelonalt), "get") # manage_wage
    assert_admin_permission(admin_manage_wage_show_url(category: wage.category,
        echelon: wage.echelon, echelonalt: wage.echelonalt), "post", params: {
          wage: { :category => wage.category, :echelon => wage.echelon, :echelonalt => wage.echelonalt,
            :basewage => 123, :basewageb => 123, :basewagec => 123, :basewaged => 123,
              :basewagee => 123 }}) # manage_wage_update
  end

  test "Admin: can admin link on home#home" do
    login_admin(:MaceWindu)
    get root_url()
    assert_select "a#admin-link"
  end

end
