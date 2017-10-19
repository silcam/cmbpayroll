require "test_helper"

class StandardChargeNotesControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  #### USER ####

  test "Loan Payments : User" do
    login_user(:Luke)

    refute_user_permission(standard_charge_notes_url(), "get") # index
    refute_user_permission(standard_charge_notes_url(), "post", params: { standard_charge_note: { note: 'note text' }}) # create
    refute_user_permission(standard_charge_note_url(standard_charge_notes(:one)), "delete") # delete
  end

  #### Supervisor ####

  test "Loan Payments : Supervisor" do
    login_supervisor(:Quigon)

    refute_user_permission(standard_charge_notes_url(), "get") # index
    refute_user_permission(standard_charge_notes_url(), "post", params: { standard_charge_note: { note: 'note text' }}) # create
    refute_user_permission(standard_charge_note_url(standard_charge_notes(:one)), "delete") # delete
  end

  #### Admin ####

  test "Loan Payments : Admin" do
    login_admin(:MaceWindu)

    assert_user_permission(standard_charge_notes_url(), "get") # index
    assert_user_permission(standard_charge_notes_url(), "post", params: { standard_charge_note: { note: 'note text' }}) # create
    assert_user_permission(standard_charge_note_url(standard_charge_notes(:one)), "delete") # delete
  end

end
