require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  test "USER: can't see Misc Payments on home#index" do
    login_user(:Luke)

    get root_url()
    assert_response :success

    assert_select "a#misc-payments-link", false, "User shouldn't be able to see misc payments"
    assert_select "a#employees-link", true, "User should be able to see employees"
  end

  test "SUPERVISOR: can see Misc Payments on home#index amd employees" do
    login_admin(:MaceWindu)

    get root_url()
    assert_response :success

    assert_select "a#misc-payments-link", true, "Admin should be able to see misc payments"
    assert_select "a#employees-link", true, "Admin should be able to see employees"
  end


end