require "test_helper"

class AdminControllerControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

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

  #### USER ####

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
