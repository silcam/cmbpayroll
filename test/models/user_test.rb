require "test_helper"


class UserTest < ActiveSupport::TestCase

  def setup
    @luke = users :Luke
  end

  test "Presence Validation" do
    params = {username: 'vader666',
              password: 'goDarkSide666!',
              person: people(:Anakin)}
    model_validation_hack_test User, params
  end

  test "Password confirmation must match" do
    assert @luke.update(password: 'something',
                              password_confirmation: 'something')
    refute @luke.update(password: 'something',
                             password_confirmation: 'something else')
  end

end
