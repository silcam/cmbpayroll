class TransferSupplemetalDays < ActiveRecord::Migration[5.1]
  def up

    # Silence almost all out the output for the migration.
    # This allows the output text to be seen. Payship operations produce a
    # significant amount of operations at verbse log levels.
    Rails.logger.level = :fatal

    period = LastPostedPeriod.get
    Employee.currently_paid.each do |e|
      say("Updating vacation balances for #{e.full_name}, checking bal in #{period}")

      ps = e.payslip_for(period)

      # Add a payslip correction for any existing supplemental days in the employee's bank to
      # their current payslip. Then clear out the existing value of the supplemental days bank.
      # This column will be deleted by a subequent migration anyways. Using payslip corrections
      # will allow the additional days to persist through multiple processes of the payslip without
      # adding too many special cases in the code.
      unless (ps.nil? || ps.accum_suppl_days.nil? || ps.accum_suppl_days == 0)
        current_payslip = e.payslip_for(LastPostedPeriod.current)
        current_payslip = Payslip.process(e, LastPostedPeriod.current) if current_payslip.nil?

        unless (current_payslip.id.nil?)
          psc = PayslipCorrection.create(payslip: current_payslip, vacation_days: ps.accum_suppl_days)
          psc.save

          say "Created PS Correction in #{current_payslip.period_month}-#{current_payslip.period_year} for #{e.full_name} for #{ps.accum_suppl_days} days", true

          # We don't change the vacation balance because that will be taken care of on the first process.
          ps.accum_suppl_days = 0
          ps.save
        else
          # For some employees, a current payslip cannot be made. Usually this is because the pay
          # is negative (Loan balance and too little pay due to missing work hours). In those cases
          # the payslip correction will need to be made after the payslip is made. Punt and let
          # someone handle it manually.
          say "Could not automatically create correction for #{e.full_name} for #{ps.accum_suppl_days} days in period #{current_payslip.period_month}-#{current_payslip.period_year}. This will need to be created manually.", true
        end
      else
        say "No balance to transfer for #{e.full_name}\n", true
      end
    end
  end

  def down
    say_with_time("There's nothing to do while undoing this change") do
    end
  end
end
