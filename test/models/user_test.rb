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


  test "Can be set to various roles" do
    @quigon = users :Quigon

    assert(@quigon.supervisor?, "is supervisor by default")

    assert_nothing_raised do
      @quigon.user!
      assert(@quigon.user?, "can be user")
    end

    assert_nothing_raised do
      @quigon.admin!
      assert(@quigon.admin?, "can be admin")
    end

    # assert_nothing_raised do
    #   @quigon.supervisor!
    #   assert(@quigon.supervisor?, "can be supervisor")
    # end
  end

  test "Default roles" do

    @dexter = User.new_with_person(first_name: 'Dexter', last_name: 'Jettster', username: 'dexter')

    @dexter.password = "nerfburger"
    @dexter.password_confirmation = "nerfburger"

    assert(@dexter.valid?, "newly created Besalisk should be valid")
    assert(@dexter.save, "save should be successful")

    assert_equal("user", @dexter.role, "should be user by default")
  end
end
