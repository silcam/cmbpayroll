require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  include ControllerTestHelper

  #### USER ####

  test "Users : User"  do
    login_user(:Luke)

    refute_user_permission(users_url(), "get") # users#index
    refute_user_permission(users_url(), "post", params: { user: {
      username: 'testu', password: 'testu', password_confirmation: 'testu',
        role: 'user', new_person: 'true' }}) # users#create
    refute_user_permission(new_user_url(), "get") # users#new

    assert_user_permission(edit_user_url(users(:Luke)), "get") # users#edit

    # can update password
    assert_user_permission(user_url(users(:Luke)), "patch", params: { user: {
      password: 'newpass', password_confirmation: 'newpass' }}) # users#update
    # can update language
    assert_user_permission(user_url(users(:Luke)), "patch", params: { user: {
      language: 'en' }}) # users#update
    # cannot change own role
    refute_user_permission(user_url(users(:Luke)), "patch", params: { user: {
      role: 'admin' }}) # users#update

    refute_user_permission(user_url(users(:Luke)), "delete") # users#destroy
  end

  test "USER: can't see limited options on user#edit" do
    login_user(:Luke)
    get edit_user_url(users(:Luke))

    # change role
    assert_select "h4#change-role", false
    assert_select "#change-role-btn", false

    # delete user
    assert_select "#delete-account-btn", false
  end

  #### Supervisor ####

  test "Users : Supervisor"  do
    login_supervisor(:Quigon)

    refute_supervisor_permission(users_url(), "get") # users#index
    refute_supervisor_permission(users_url(), "post", params: { user: {
      username: 'testu', password: 'testu', password_confirmation: 'testu',
        role: 'user', new_person: 'true' }}) # users#create
    refute_supervisor_permission(new_user_url(), "get") # users#new

    refute_supervisor_permission(edit_user_url(users(:Luke)), "get") # users#edit
    refute_supervisor_permission(user_url(users(:Luke)), "patch", params: { user: {
      password: 'newpass', password_confirmation: 'newpass' }}) # users#update

    refute_supervisor_permission(user_url(users(:Quigon)), "delete") # users#destroy
  end

  test "Supervisor: can't see limited options on user#edit" do
    login_supervisor(:Yoda)
    get edit_user_url(users(:Luke))

    # change role
    assert_select "h4#change-role", false
    assert_select "#change-role-btn", false

    # delete user
    assert_select "#delete-account-btn", false
  end

  #### Admin ####

  test "Users : Admin"  do
    login_admin(:MaceWindu)

    assert_admin_permission(users_url(), "get") # users#index
    assert_admin_permission(users_url(), "post", params: { user: {
      username: 'testu', password: 'testu', password_confirmation: 'testu',
        role: 'user', new_person: 'true' }}) # users#create
    assert_admin_permission(new_user_url(), "get") # users#new
    assert_admin_permission(edit_user_url(users(:Luke)), "get") # users#edit

    assert_admin_permission(user_url(users(:Luke)), "patch", params: { user: {
      password: 'newpass', password_confirmation: 'newpass' }}) # users#update
    assert_admin_permission(user_url(users(:Luke)), "patch", params: { user: {
      language: 'en' }}) # users#update
    # admins can change role
    assert_admin_permission(user_url(users(:Luke)), "patch", params: { user: {
      role: 'admin' }}) # users#update

    assert_admin_permission(user_url(users(:Quigon)), "delete") # users#destroy
  end

  test "Admin: can see all options on user#edit" do
    login_admin(:MaceWindu)
    get edit_user_url(users(:Luke))

    # change role
    assert_select "h4#change-role"
    assert_select "#change-role-btn"

    # delete user
    assert_select "#delete-account-btn"
  end

end
