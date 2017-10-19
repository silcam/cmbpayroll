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

    assert(policy.can?(:create, Department), "admins can create Department")
    assert(policy.can?(:read, Department), "admins can read Department")
    assert(policy.can?(:update, Department), "admins can update Department")
    assert(policy.can?(:destroy, Department), "admins can destroy Department")

    assert(policy.can?(:create, Loan), "admins can create Loans")
    assert(policy.can?(:read, Loan), "admins can read Loans")
    assert(policy.can?(:update, Loan), "admins can update Loans")
    assert(policy.can?(:destroy, Loan), "admins can destroy Loans")

    assert(policy.can?(:create, LoanPayment), "admins can create Loan Payments")
    assert(policy.can?(:read, LoanPayment), "admins can read Loan Payments")
    assert(policy.can?(:update, LoanPayment), "admins can update Loan Payments")
    assert(policy.can?(:destroy, LoanPayment), "admins can destroy Loan Payments")

    assert(policy.can?(:create, StandardChargeNote), "admins can create Standard Charge Notes")
    assert(policy.can?(:read, StandardChargeNote), "admins can read Standard Charge Notes")
    assert(policy.can?(:update, StandardChargeNote), "admins can update Standard Charge Notes")
    assert(policy.can?(:destroy, StandardChargeNote), "admins can destroy Standard Charge Notes")

    assert(policy.can?(:read, AdminController), "admins can see Admin Page")
    assert(policy.can?(:read, Wage), "admins admin wages")
    assert(policy.can?(:update, Wage), "admins admin wages")
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

    obiwan_charge = @obiwan.charges.create!(amount: 10, date: '2017-08-15', note: 'test')
    assert(@obiwan.charges.size >= 1, "obiwan has charges")

    chewie_charge = @chewie.charges.create!(amount: 10, date: '2017-08-15', note: 'test')
    assert(@chewie.charges.size >= 1, "chewie has charges")

    assert(policy.can?(:read, obiwan_charge), "Quigon can read Charges from Report") # if for a report
    refute(policy.can?(:read, chewie_charge), "Quigon can't read Charges from Non-Report") # if not for a report

    refute(policy.can?(:update, Charge), "Quigon can't update Charges")
    refute(policy.can?(:destroy, Charge), "Quigon can't destroy Charges")

    refute(policy.can?(:create, Department), "Supervisors can't create Department")
    refute(policy.can?(:read, Department), "Supervisors can't read Department")
    refute(policy.can?(:update, Department), "Supervisors can't update Department")
    refute(policy.can?(:destroy, Department), "Supervisors can't destroy Department")

    obiwan_loan = @obiwan.loans.create!(amount: 15000, comment: 'asd', origination: DateTime.now, term: "six_month_term")
    obiwan_loan_pmnt = obiwan_loan.loan_payments.create!(amount: 5000, date: DateTime.now)

    han_loan = @han.loans.create!(amount: 15000, comment: 'asd', origination: DateTime.now, term: "six_month_term")
    han_loan_pmnt = han_loan.loan_payments.create!(amount: 5000, date: DateTime.now)

    refute(policy.can?(:create, Loan), "Quigon can't create Loans")
    assert(policy.can?(:read, obiwan_loan), "Quigon can read Loans for report") # Can read for reports
    refute(policy.can?(:read, han_loan), "Quigon can't read Loans for other") # Can't read for others
    refute(policy.can?(:update, Loan), "Quigon can't update Loans")
    refute(policy.can?(:destroy, Loan), "Quigon can't destroy Loans")

    refute(policy.can?(:create, LoanPayment), "Quigon can't create Loan Payments")
    assert(policy.can?(:read, obiwan_loan_pmnt), "Quigon can read Loan Payments for reports") # Can read for reports
    refute(policy.can?(:read, han_loan_pmnt), "Quigon can't read Loan Payments for others") # Can't read for reports
    refute(policy.can?(:update, LoanPayment), "Quigon can't update Loan Payments")
    refute(policy.can?(:destroy, LoanPayment), "Quigon can't destroy Loan Payments")

    refute(policy.can?(:create, StandardChargeNote), "supervisors can't create Standard Charge Notes")
    refute(policy.can?(:read, StandardChargeNote), "supervisors can't read Standard Charge Notes")
    refute(policy.can?(:update, StandardChargeNote), "supervisors can't update Standard Charge Notes")
    refute(policy.can?(:destroy, StandardChargeNote), "supervisors can't destroy Standard Charge Notes")

    refute(policy.can?(:read, AdminController), "non-admins cannot see Admin Page")
    refute(policy.can?(:read, Wage), "non-admins cannot admin wages")
    refute(policy.can?(:update, Wage), "non-admins cannot admin wages")
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

    luke_charge = @luke_emp.charges.create!(amount: 10, date: '2017-08-15', note: 'test')
    han_charge = @han.charges.create!(amount: 10, date: '2017-08-15', note: 'test')
    assert(@luke_emp.charges.size >= 1, "luke has charges")

    assert(policy.can?(:read, luke_charge), "Luke can see own Charges") # Can see own
    assert(@han.charges.size >= 1, "han has charges") # Can't see others
    refute(policy.can?(:read, han_charge), "Luke can't read Charges from Han")

    refute(policy.can?(:update, Charge), "Luke can't update Charges")
    refute(policy.can?(:destroy, Charge), "Luke can't destroy Charges")

    refute(policy.can?(:create, Department), "Luke can't create Department")
    refute(policy.can?(:read, Department), "Luke can't read Department")
    refute(policy.can?(:update, Department), "Luke can't update Department")
    refute(policy.can?(:destroy, Department), "Luke can't destroy Department")

    luke_loan = @luke_emp.loans.create!(amount: 15000, comment: 'asd', origination: DateTime.now, term: "six_month_term")
    luke_loan_pmnt = luke_loan.loan_payments.create!(amount: 5000, date: DateTime.now)

    han_loan = @han.loans.create!(amount: 15000, comment: 'asd', origination: DateTime.now, term: "six_month_term")
    han_loan_pmnt = han_loan.loan_payments.create!(amount: 5000, date: DateTime.now)

    refute(policy.can?(:create, Loan), "Luke can't create Loans")
    assert(policy.can?(:read, luke_loan), "Luke can't read Loans") # Can read own
    refute(policy.can?(:read, han_loan), "Luke can't read Loans") # Can't read other

    refute(policy.can?(:update, Loan), "Luke can't update Loans")
    refute(policy.can?(:destroy, Loan), "Luke can't destroy Loans")

    refute(policy.can?(:create, LoanPayment), "Luke can't create Loan Payments")
    assert(policy.can?(:read, luke_loan_pmnt), "Luke can't read Loan Payments") # Can read own
    refute(policy.can?(:read, han_loan_pmnt), "Luke can't read Loan Payments") # Can't read other

    refute(policy.can?(:update, LoanPayment), "Luke can't update Loan Payments")
    refute(policy.can?(:destroy, LoanPayment), "Luke can't destroy Loan Payments")

    refute(policy.can?(:read, AdminController), "non-admins cannot see Admin Page")
    refute(policy.can?(:read, Wage), "non-admins cannot admin wages")
    refute(policy.can?(:update, Wage), "non-admins cannot admin wages")
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

    refute(policy.can?(:create, Department), "Jar Jar can't create Department")
    refute(policy.can?(:read, Department), "Jar Jar can't read Department")
    refute(policy.can?(:update, Department), "Jar Jar can't update Department")
    refute(policy.can?(:destroy, Department), "Jar Jar can't destroy Department")

    luke_loan = @luke_emp.loans.create!(amount: 15000, comment: 'asd', origination: DateTime.now, term: "six_month_term")
    luke_loan_pmnt = luke_loan.loan_payments.create!(amount: 5000, date: DateTime.now)
    refute(policy.can?(:create, Loan), "Jar Jar can't create Loans")
    refute(policy.can?(:read, luke_loan), "Jar Jar can't read Loans")
    refute(policy.can?(:update, Loan), "Jar Jar can't update Loans")
    refute(policy.can?(:destroy, Loan), "Jar Jar can't destroy Loans")

    refute(policy.can?(:create, LoanPayment), "Jar Jar can't create Loan Payments")
    refute(policy.can?(:read, luke_loan_pmnt), "Jar Jar can't read Loan Payments")
    refute(policy.can?(:update, LoanPayment), "Jar Jar can't update Loan Payments")
    refute(policy.can?(:destroy, LoanPayment), "Jar Jar can't destroy Loan Payments")

    refute(policy.can?(:create, StandardChargeNote), "users can't create Standard Charge Notes")
    refute(policy.can?(:read, StandardChargeNote), "users can't read Standard Charge Notes")
    refute(policy.can?(:update, StandardChargeNote), "users can't update Standard Charge Notes")
    refute(policy.can?(:destroy, StandardChargeNote), "users can't destroy Standard Charge Notes")

    refute(policy.can?(:read, AdminController), "non-admins cannot see Admin Page")
    refute(policy.can?(:read, Wage), "non-admins cannot admin wages")
    refute(policy.can?(:update, Wage), "non-admins cannot admin wages")
  end
end
