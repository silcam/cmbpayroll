require 'test_helper'
require "application_system_test_case"

# Covers the rails-ujs mechanism behind every destructive link in the app.
#
# About ten views render `link_to ..., method: :delete, data: { confirm: ... }`
# -- loans, work_loans, children, employees, vacations, bonuses, departments,
# users. None of that is an ordinary link. rails-ujs has to intercept the
# click, raise window.confirm, and then build and submit a hidden form carrying
# the DELETE verb and the CSRF token. If it is not bound, the browser just
# follows the href as an ordinary GET. On most of those views that is silent --
# a GET to the show action, no error, no flash, no clue. Children are the
# exception: routes declare `resources :children, except: [:show]`, so the
# degraded GET raises a routing error here rather than doing nothing quietly.
# Either way the record survives, which is what the assertions below pin down.
#
# A controller test cannot see any of this. children_controller_test.rb
# already asserts both halves separately and still misses it: it issues
# `delete child_url(...)` directly, which always exercises the destroy action
# regardless of what the page does, and it asserts `a#delete-child-link` is
# rendered, which says nothing about what clicking it produces.
#
# This is not hypothetical for the 6.1 upgrade. The same class of breakage has
# already shipped once on this branch: see the comment in
# app/views/admin/estimate_pay.html.erb, where form_with rendered with no
# data-remote under 6.1 defaults and UJS never fired. estimate_pay_test.rb
# exists to catch that one form. Nothing covered the destroy links.
#
# Children are the vehicle, not the subject. Luke has exactly one child in the
# fixtures, so the index carries exactly one delete link -- the id is repeated
# per row, so a multi-child employee would make `find` ambiguous. Any of the
# ten views would do; the mechanism is shared, so one is enough.
class DeleteLinkTest < ApplicationSystemTestCase
  def setup
    @employee = employees :Luke
    @child = children :LukeJr
  end

  # Addressed by id, never by the link's text: t(:Destroy) renders in
  # current_user.language, the locale trap documented on wait_for_login.
  test "a destroy link deletes the record once the confirm is accepted" do
    log_in_admin

    visit employee_children_path(@employee)
    assert_selector 'a#delete-child-link', count: 1

    accept_confirm do
      find('a#delete-child-link').click
    end

    # accept_confirm raises Capybara::ModalNotFound if no dialog appears, so
    # reaching this line already proves UJS intercepted the click. The path
    # assertion then proves it went on to issue a real DELETE: this is
    # ChildrenController#destroy's redirect, and anything short of that leaves
    # the browser on /children/:id.
    assert_current_path employee_path(@employee)
    refute Child.exists?(@child.id), 'the child survived an accepted delete'
  end

  test "dismissing the confirm leaves the record alone" do
    log_in_admin

    visit employee_children_path(@employee)
    assert_selector 'a#delete-child-link', count: 1

    dismiss_confirm do
      find('a#delete-child-link').click
    end

    # Re-visiting forces a fresh round trip rather than asserting against a
    # page that never changed, so a DELETE wrongly sent despite the dismissal
    # has to beat this request to hide -- and it could not, because its own
    # redirect would have to resolve first.
    visit employee_children_path(@employee)
    assert_selector 'a#delete-child-link', count: 1
    assert Child.exists?(@child.id), 'the child was deleted despite the dismissal'
  end
end
