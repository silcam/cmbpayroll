require "test_helper"
require Rails.root.join('db', 'migrate', '20190704102431_transfer_supplemetal_days.rb')

class SupplementaryDaysMigrationTest < ActiveSupport::TestCase

  let(:migration) { TransferSupplemetalDays }
  let(:previous) {20190626143506} # before suppl changes
  let(:target) {20190704102431} # after suppl changes

  test "Supplemental Days Migration" do
    assert(:migration)

    existing_value = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    # Set this way back so I can do some trickery
    lpp = LastPostedPeriod.first_or_initialize
    lpp.update year: 2017, month: 1
    lpp.save!

    # Suppress the migration output messages, if you have trouble with this
    # test, it may be good to remove this to see what's going on.
    # NB. the db has been rolled back but the business logic is the same.
    ActiveRecord::Migrator.migrate(['db/migrate'], previous)
    Payslip.reset_column_information

    employee = return_valid_employee()
    employee.first_name = "MigrationTester"
    employee.save

    prev_period = Period.current.previous

    # Set initial values.
    prev_vac_pay_bal = 394875
    prev_vac_bal = 24.3
    set_previous_vacation_balances(employee, prev_period, prev_vac_pay_bal, prev_vac_bal)
    generate_work_hours(employee, prev_period)

    previous_payslip = employee.payslip_for(prev_period.previous)
    assert_equal(24.3, previous_payslip.vacation_balance.round(2), "correct previous vac balance")
    assert_equal(0.17, previous_payslip.period_suppl_days.round(2), "prev suppl days correct")

    payslip = Payslip.process(employee, prev_period)
    payslip.accum_suppl_days = 0.33
    payslip.save

    assert_equal(25.8 + 0.17, payslip.vacation_balance.round(2), "has correct vac balance")
    assert_equal(1.5 + 0.17, payslip.vacation_earned.round(2), "has correct vac earned")
    assert_equal(0.33, payslip.accum_suppl_days.round(2), "has correct suppl days")
    assert_equal(0.17, payslip.period_suppl_days.round(2), "period suppl days correct")

    # Verify no payslip corrections, control
    assert_equal(0, employee.payslip_corrections.for_period(prev_period).count)
    assert_equal(0, employee.payslip_corrections.for_period(prev_period.next).count)

    # Reset LPP to the month before the current one.
    lpp = LastPostedPeriod.first_or_initialize
    lpp.update year: prev_period.year, month: prev_period.month
    lpp.save!

    ActiveRecord::Migrator.migrate(['db/migrate'], target)
    # Reset model and retrieve the object again.
    Payslip.reset_column_information
    payslip.reload

    # Verify that the payslip correction was created correctly
    assert_equal(1, employee.payslip_corrections.for_period(prev_period.next).count, "has created a payslip correction")
    assert_equal(0.33, employee.payslip_corrections.first.vacation_days, "has correct correction")

    period = LastPostedPeriod.current
    assert_equal(prev_period.next, period, "these should be the same")

    # process and apply any correction.
    generate_work_hours(employee, period)
    payslip = Payslip.process(employee, period)

    # Base + period days
    refute(payslip.accum_suppl_days, "should be cleared by the migration (nil)")

    # prior balance + 1.5 + suppl + correction
    assert_equal(1.5 + 0.17, payslip.vacation_earned.round(2), "has correct vac earned")
    assert_equal(0.17, payslip.period_suppl_days.round(2), "monthly suppl days should be same as last month")
    assert_equal((25.96 + (1.5 + 0.17) + 0.33).round(2), payslip.vacation_balance.round(2), "balance is correct")
                 # previous balance + this month's balance + 0.33

    # attempt to reprocess the payslip and verify that the numbers are still correct.
    payslip = Payslip.process(employee, period)

    assert_equal(0.17, payslip.period_suppl_days.round(2), "suppl days correct")
    assert_equal((25.96 + (1.5 + 0.17) + 0.33).round(2), payslip.vacation_balance.round(2), "balance didn't change on reprocess")
    assert_equal(1.5 + 0.17, payslip.vacation_earned.round(2), "vac earned is unchanged") # ???
    refute(payslip.accum_suppl_days, "suppl days ain't around no more.")

    ActiveRecord::Migration.verbose = existing_value
  end

end
