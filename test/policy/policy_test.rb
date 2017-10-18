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

    assert(policy.can?(:create, Bonus), "admins can create Bonuses")
    assert(policy.can?(:read, Bonus), "admins can read Bonuses")
    assert(policy.can?(:update, Bonus), "admins can update Bonuses")
    assert(policy.can?(:destroy, Bonus), "admins can destroy Bonuses")

    assert(policy.can?(:create, Charge), "admins can create Charges")
    assert(policy.can?(:read, Charge), "admins can read Charges")
    assert(policy.can?(:update, Charge), "admins can update Charges")
    assert(policy.can?(:destroy, Charge), "admins can destroy Charges")
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

    refute(policy.can?(:create, Bonus), "Quigon can't create Bonuses")
    refute(policy.can?(:read, Bonus), "Quigon can't read Bonuses")
    refute(policy.can?(:update, Bonus), "Quigon can't update Bonuses")
    refute(policy.can?(:destroy, Bonus), "Quigon can't destroy Bonuses")

    refute(policy.can?(:create, Charge), "Quigon can't create Charges")

    # if for a report
    obiwan_charge = @obiwan.charges.create!(amount: 10, date: '2017-08-15', note: 'test')
    assert(@obiwan.charges.size >= 1, "obiwan has charges")
    assert(policy.can?(:read, obiwan_charge), "Quigon can read Charges from Report")
    # if not for a report
    chewie_charge = @chewie.charges.create!(amount: 10, date: '2017-08-15', note: 'test')
    assert(@chewie.charges.size >= 1, "chewie has charges")
    refute(policy.can?(:read, chewie_charge), "Quigon can't read Charges from Non-Report")

    refute(policy.can?(:update, Charge), "Quigon can't update Charges")
    refute(policy.can?(:destroy, Charge), "Quigon can't destroy Charges")
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

    refute(policy.can?(:create, Bonus), "Luke can't create Bonuses")
    refute(policy.can?(:read, Bonus), "Luke can't read Bonuses")
    refute(policy.can?(:update, Bonus), "Luke can't update Bonuses")
    refute(policy.can?(:destroy, Bonus), "Luke can't destroy Bonuses")

    refute(policy.can?(:create, Charge), "Luke can't create Charges")

    # Can see own
    luke_charge = @luke_emp.charges.create!(amount: 10, date: '2017-08-15', note: 'test')
    assert(@luke_emp.charges.size >= 1, "luke has charges")
    assert(policy.can?(:read, luke_charge), "Luke can see own Charges")
    # Can't see others
    han_charge = @han.charges.create!(amount: 10, date: '2017-08-15', note: 'test')
    assert(@han.charges.size >= 1, "han has charges")
    refute(policy.can?(:read, han_charge), "Luke can't read Charges from Han")

    refute(policy.can?(:update, Charge), "Luke can't update Charges")
    refute(policy.can?(:destroy, Charge), "Luke can't destroy Charges")
  end

  test "Policy for Non-Privleged Users " do
    assert(@jarjar.user?, "JarJar is a user")

    policy = AccessPolicy.new(@jarjar)

    refute(policy.can?(:read, @luke_emp), "Jar Jar can't read/see Luke")
    refute(policy.can?(:update, @luke_emp), "Jar Jar can't update Luke")
    refute(policy.can?(:destroy, @luke_emp), "Jar Jar can't destroy Luke")
    refute(policy.can?(:create, Employee), "Jar Jar can't create employees")

    refute(policy.can?(:create, Bonus), "Jar Jar can't create Bonuses")
    refute(policy.can?(:read, Bonus), "Jar Jar can't read Bonuses")
    refute(policy.can?(:update, Bonus), "Jar Jar can't update Bonuses")
    refute(policy.can?(:destroy, Bonus), "Jar Jar can't destroy Bonuses")

    refute(policy.can?(:create, Charge), "Jar Jar can't create Charges")
    luke_charge = @luke_emp.charges.create!(amount: 10, date: '2017-08-15', note: 'test')
    refute(policy.can?(:read, luke_charge), "Jar Jar can't see Charges")
    refute(policy.can?(:update, Charge), "Jar Jar can't update Charges")
    refute(policy.can?(:destroy, Charge), "Jar Jar can't destroy Charges")
  end

end
