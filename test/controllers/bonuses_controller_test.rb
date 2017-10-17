require "test_helper"

class BonusesControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  #### USER ####

  test "Things a User CANNOT do"  do
    login_user(:Luke)

    refute_user_permission(new_bonus_url(), "get") # new
    refute_user_permission(bonuses_url(), "post", params: { name: 'Test Bonus', bonus_type: 'percentage', quantity: '15.0' }) # create
    refute_user_permission(bonuses_url(), "get") # index
    refute_user_permission(bonus_url(Bonus.all.first), "get") # show bonus
    refute_user_permission(edit_bonus_url(Bonus.all.first), "get") # show edit page
    refute_user_permission(assign_employee_bonuses_url(employees(:Han)), "patch", params: {bonus: {} }) # assign
    refute_user_permission(unassign_employee_bonuses_url(employees(:Han)), "patch", params: { bonus: {} }) #unassign
    refute_user_permission(bonus_url(Bonus.all.first), "patch", params: { bonus_type: 'fixed' }) # update bonus
    refute_user_permission(bonus_url(Bonus.all.first), "delete") # delete bonus
  end

  test "USER: check bonus button is missing" do
    login(:Luke, "user")
    get root_url()
    assert_select "a[href=\"/bonuses\"]", false
  end

  test "USER: check assign bonus link is missing for self" do
    login(:Luke, "user")
    get employee_url(employees(:Luke))
    assert_select "a#assign-bonuses-link", false
  end

  test "USER: check unassign bonus button/display is missing" do
    login_user(:Luke)

    luke = employees(:Luke)

    if (luke.bonuses.size == 0)
      luke.bonuses << Bonus.all.first
    end
    assert(luke.bonuses.size > 0, "must have bonuses")

    get employee_url(luke)

    assert_select "p#no-bonuses", false
    assert_select "th#unassign-header", false
    assert_select "input.unassign-button", false
  end

  #### SUPERVISOR ####

  test "Things a supervisor CANNOT do"  do
    login_supervisor(:Quigon)

    refute_supervisor_permission(new_bonus_url(), "get") # new
    refute_supervisor_permission(bonuses_url(), "post", params: { name: 'Test Bonus', bonus_type: 'percentage', quantity: '15.0' }) # create
    refute_supervisor_permission(bonuses_url(), "get") # index
    refute_supervisor_permission(bonus_url(Bonus.all.first), "get") # show bonus
    refute_supervisor_permission(edit_bonus_url(Bonus.all.first), "get") # show edit page
    refute_supervisor_permission(assign_employee_bonuses_url(employees(:Han)), "patch", params: {bonus: {} }) # assign
    refute_supervisor_permission(unassign_employee_bonuses_url(employees(:Han)), "patch", params: { bonus: {} }) #unassign
    refute_supervisor_permission(bonus_url(Bonus.all.first), "patch", params: { bonus_type: 'fixed' }) # update bonus
    refute_supervisor_permission(bonus_url(Bonus.all.first), "delete") # delete bonus
  end

  test "SUPERVISOR: check bonus button is missing" do
    login_supervisor(:Quigon)
    get root_url()
    assert_select "a[href=\"/bonuses\"]", false
  end

  test "SUPERVISOR: check assign bonus link is missing for report" do
    login_supervisor(:Quigon)
    get employee_url(employees(:Obiwan))
    assert_select "a#assign-bonuses-link", false
  end

  test "SUPERVISOR: check unassign bonus button/display is missing" do
    login_supervisor(:Quigon)

    emp = employees(:Obiwan)

    if (emp.bonuses.size == 0)
      emp.bonuses << Bonus.all.first
    end
    assert(emp.bonuses.size > 0, "must have bonuses")

    get employee_url(emp)

    assert_select "p#no-bonuses", false
    assert_select "th#unassign-header", false
    assert_select "input.unassign-button", false
  end

  #### ADMIN ####

  test "Admin can do things" do
    login_admin(:MaceWindu)

    assert_admin_permission(new_bonus_url(), "get") # new
    assert_admin_permission(bonuses_url(), "post", params: { bonus: { name: 'Test Bonus', comment: 'Test Bonus',
        bonus_type: 'percentage', quantity: '15.0' }}) # create
    assert_admin_permission(bonuses_url(), "get") # index
    assert_admin_permission(bonus_url(Bonus.all.first), "get") # show bonus
    assert_admin_permission(edit_bonus_url(Bonus.all.first), "get") # show edit page
    assert_admin_permission(assign_employee_bonuses_url(employees(:Han)), "patch", params: {bonus: { "#{Bonus.all.first.id}" => 1 }}) # assign
    assert_admin_permission(unassign_employee_bonuses_url(employees(:Han)), "patch", params: { bonus: { b: Bonus.all.first.id }}) #unassign
    assert_admin_permission(bonus_url(Bonus.all.first), "patch", params: { bonus: { bonus_type: 'fixed' }}) # update bonus
    assert_admin_permission(bonus_url(Bonus.all.first), "delete") # delete bonus
  end

  test "Admin: check bonus button is there" do
    login_admin(:MaceWindu)
    get root_url()
    assert_select "a[href=\"/bonuses\"]", true
  end

  test "Admin: check assign bonus link is missing for report" do
    login_admin(:MaceWindu)
    get employee_url(employees(:Han))
    assert_select "a#assign-bonuses-link", "Assign"
  end

  test "Admin: check unassign bonus button/display is missing" do
    login_admin(:MaceWindu)

    emp = employees(:Han)

    if (emp.bonuses.size == 0)
      emp.bonuses << Bonus.all.first
    end
    assert(emp.bonuses.size > 0, "must have bonuses")

    get employee_url(emp)

    assert_select "p#no-bonuses", false
    assert_select "th#unassign-header", true
    assert_select "input.unassign-button", true
  end

end
