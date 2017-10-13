require "test_helper"

class PolicyTest < ActiveSupport::TestCase

  def setup
    @luke_usr = users :Luke
    @luke_emp = employees :Luke

    @quigon = users :Quigon
    @jarjar = users :JarJar
    @macewindu = users :MaceWindu

    @chewie = employees :Chewie
    @obiwan = employees :Obiwan
    @han = employees :Han
  end

  test "Policy for Administrators" do

    assert(@macewindu.admin?, "Mace should be an admin")
    policy = AccessPolicy.new(@macewindu)

    assert(policy.can?(:create, @chewie), "admins can create Employees")
    assert(policy.can?(:read, @chewie), "admins can read Employees")
    assert(policy.can?(:update, @chewie), "admins can update Employees")
    assert(policy.can?(:destroy, @chewie), "admins can destroy Employees")
  end

  test "Policy for Supervisors " do
    assert(@quigon.supervisor?, "Quigon should be a supervisor")
    assert(@obiwan)

    refute_equal(@quigon.person.id, @chewie.supervisor.person.id,
        "Quigon doesn't supervise Chewie")
    assert_equal(@quigon.person.id, @obiwan.supervisor.person.id,
        "Quigon supervises Obiwan")

    policy = AccessPolicy.new(@quigon)

    refute(policy.can?(:read, @chewie), "Quigon can't see(read) Chewie")
    assert(policy.can?(:read, @obiwan), "Quigon can see(read) Obiwan")
    refute(policy.can?(:read, @quigon), "Quigon can't see(read) self")

    refute(policy.can?(:update, @quigon), "Quigon cannot modify self")
    refute(policy.can?(:destroy, @quigon), "Quigon cannot destroy self")
    assert(policy.can?(:update, @obiwan), "Quigon cannot modify direct reports")
    refute(policy.can?(:destroy, @obiwan), "Quigon cannot destroy direct reports")
    refute(policy.can?(:create, Employee), "Quigon can't create employees")
  end

  test "Multi-level Supervisors " do
    # Yoda -> Han -> Chewie
    # Yoda should be able to see Chewie (I think)
    #assert(false, "Write this test")
  end

  test "Policy for Self " do
    refute(@luke_usr.supervisor?, "Luke is not supervisor")
    refute(@luke_usr.admin?, "Luke is not admin")
    assert(@luke_usr.user?, "Luke is a user")

    policy = AccessPolicy.new(@luke_usr)

    assert(policy.can?(:read, @luke_emp), "Luke(user) and read Luke(employee)")
    refute(policy.can?(:read, @han), "Luke(user) cannot read Han(employee)")

    refute(policy.can?(:destroy, @luke_emp), "Luke(user) cannot destroy self")
    refute(policy.can?(:update, @luke_emp), "Luke(user) cannot modify self")
    refute(policy.can?(:destroy, @han), "Luke(user) cannot destroy Han")
    refute(policy.can?(:update, @han), "Luke(user) cannot modify Han")
    refute(policy.can?(:create, Employee), "Luke(user) can't read employees")
  end

  test "Policy for Non-Privleged Users " do
    assert(@jarjar.user?, "JarJar is a user")

    policy = AccessPolicy.new(@jarjar)

    refute(policy.can?(:read, @luke_emp), "Jar Jar can't read/see Luke")
    refute(policy.can?(:update, @luke_emp), "Jar Jar can't update Luke")
    refute(policy.can?(:destroy, @luke_emp), "Jar Jar can't destroy Luke")
    refute(policy.can?(:create, Employee), "Jar Jar can't create employees")
  end

end
