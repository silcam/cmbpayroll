require 'test_helper'

class EmployeesIndexTest < Capybara::Rails::TestCase

  def setup
    @jarjar = users :JarJar
  end

  test "non-employee user views employee index" do
    log_in(@jarjar)
    visit employees_path
    assert_current_path employees_path
  end
end
