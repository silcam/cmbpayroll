class JournalReport

  def produce_report(period)
    # Employees that are exceptions.
    @kain = 308
    @kimbi = 278

    @report_data = []
    @kimbi_vac = 0

    @dept_charge_results = find_results_from_report("DepartmentChargeReport", period,
      [:department_cnps, :credit_foncier, :vacation_pay, :employee_fund])
    @employee_deduction_results = find_results_from_report("EmployeeDeductionReport", period,
      [:net_pay, :loan_payment, :salary_advance, :amical, :union, :bank_transfer, :loc_transfer])
    @vacation_report_results = find_results_from_report("VacationReport", period,
      [:cash_pay, :total_charge, :dept_cnps, :dept_credit_foncier])

    #################################### DEBITS ##################################

    ####  1. Department Charges (find total charge per department)
    # NOTE: there are multiple departments with same name but different ids
    results = DepartmentChargeReport.new(period: period.to_s).results.hashes
    dept_results = {}
    results.each do |r|
      dept_results[r[:department_name]] = [r[:department_id], 0] unless dept_results.has_key?(r[:department_name])
      dept_results[r[:department_name]][1] += r[:total_charge]

      if (r[:department_id]) == Employee.find(@kimbi).department.id
        @kimbi_vac = r[:vacation_pay].to_i
        dept_results[r[:department_name]][1] = ( r[:total_tax] + r[:department_cnps] + r[:credit_foncier] )
      end
    end

    dept_results.each do |k,v|
      dept = Department.find(v[0])
      dept_note = "Employee payroll charges - #{period.short_name}"
      dept_note += " (Kimbi total tax + dept cnps + dept cf)" if (k) == Employee.find(@kimbi).department.id
      record_line("#{dept.name} - Employee Salaries", dept_note, dept.account, @report_data, v[1], 0)
    end

    ####  2. Vacation DEPT CHARGE
    record_line("P/R EMPLOYEES - A/P VACATION YEAR END RECLASSIFICATION", "P/R EMPLOYEES - A/P VACATION YEAR END RECLASSIFICATION", "2310011PREM", @report_data, @vacation_report_results[:total_charge], 0)

    ####  3. Misc. Deductions (Travel, telephone, etc.)
    results = Deduction.where("amount < 0").joins(:payslip).where("period_month = ? and period_year = ?", period.month, period.year)

    results.each do |r|
      deduction_acct = r.payslip.employee.department.account
      deduction_note = "#{period.short_name}, #{r.note} Allowance to #{r.payslip.employee.full_name}"
      dept_name = r.payslip.employee.department.name

      # FIXME: This should only be G&A for those in Admin, each dept should have cost centers around these types of debits.
      if (r.note.downcase == "taxi")
        dept_name = dept_name.concat(" - LOCAL TRAVEL")
        #deduction_acct = "Verify 637401ADM17"
      elsif (r.note.downcase == "telephone" || r.note.downcase == "airtime")
        dept_name = dept_name.concat(" - TELECOMMUNICATION")
        #deduction_acct = "Verify 637401ADM17"
      end

      record_line(dept_name, deduction_note, deduction_acct, @report_data, r.amount.abs, 0)
    end

    #################################### CREDITS ##################################

    ####  1. CNPS paid by dept for employees + from Vac report.
    total_cnps = @dept_charge_results[:department_cnps] + @vacation_report_results[:dept_cnps]
    record_line("P/R EMPLOYEES - A/P CNPS","Employee payroll charges - #{period.short_name} (depts + vac report)", "2341011PREM", @report_data, 0, total_cnps)

    ####  2. Credit Foncier paid by dept for employees + from Vac report
    total_credit_foncier = @dept_charge_results[:credit_foncier] + @vacation_report_results[:dept_credit_foncier]
    record_line("P/R EMPLOYEES - A/P TAXES","Employee payroll charges - #{period.short_name} (depts + vac report)", "2340011PREM", @report_data, 0, total_credit_foncier)

    ####  3. Vacation pay charged to employees this month (FROM dept charge report, total, less kimbi)
    vac_pay_charged = ( @dept_charge_results[:vacation_pay] - @kimbi_vac )
    record_line("P/R EMPLOYEES - A/P VACATION YEAR END RECLASSIFICATION-CREDIT", "Employee payroll charges - #{period.short_name} (less Kimbi)", "2310011PREM", @report_data, 0, vac_pay_charged)

    ####  4. Employee Fund Total
    record_line("EMP BENEFITS - INTERNAL INCOME", "Employee payroll charges - #{period.short_name}", "419001EMB22", @report_data, 0, @dept_charge_results[:employee_fund])

    ####  5. Payroll Given to Office Accounts so they can pay there.
    ####     Basically, sum of net wage for people Who work in various offices
    @bro_pay_total = Deduction.joins(:payslip => :employee).
        where("location = ? and deduction_type = ? and employee_id <> ? and period_month = ? and period_year = ?",
            Employee.locations[:bro], Charge.charge_types[:location_transfer], @kain, period.month, period.year).sum("amount")
    @gnro_pay_total = Deduction.joins(:payslip => :employee).
        where("location = ? and deduction_type = ? and period_month = ? and period_year = ?",
            Employee.locations[:gnro], Charge.charge_types[:location_transfer], period.month, period.year).sum("amount")
    @kain_pay_total = Deduction.joins(:payslip => :employee).
        where("location = ? and deduction_type = ? and employee_id = ? and period_month = ? and period_year = ?",
            Employee.locations[:bro], Charge.charge_types[:location_transfer], @kain, period.month, period.year).sum("amount")

    record_line("P/R EMPLOYEES - A/R MISC", "Employee payroll charges - #{period.short_name} - GNRO", "1140011PREM", @report_data, 0, @gnro_pay_total)
    record_line("LS BDA REG OFF - SUSPENSE CFA", "Employee payroll charges - #{period.short_name} - BRO", "190501LSB13", @report_data, 0, @bro_pay_total)
    record_line("#4418.2 KOM EDUCATION PILOT-EMPLOYEE SALARY", "Employee payroll charges - #{period.short_name} - BRO Kain", "612001KEP55", @report_data, 0, @kain_pay_total)

    ####  6. Salary Advances Totaled (This is also bank transfers) LESS KIMBI
    kimbi_pay = Deduction.joins(:payslip => :employee).where("employee_id = ? AND period_month = ? and period_year = ? and deduction_type = 1", @kimbi, period.month, period.year).sum("amount")
    adv_total = ( @employee_deduction_results[:salary_advance] + @employee_deduction_results[:bank_transfer] - kimbi_pay )
    record_line("P/R EMPLOYEES - SAL ADVANCES", "Employee payroll charges - #{period.short_name} (all bank xfer, all sal adv) less kimbi","1145011PREM", @report_data, 0, adv_total)

    ####  7. Union Dues Collected
    record_line("A/P - UNION DUES", "Employee payroll charges - #{period.short_name}","2349011PREM", @report_data, 0, @employee_deduction_results[:union])

    ####  8. Loan Payments Collected
    record_line("P/R EMPLOYEES - LOANS", "Collected from employees - Loans - #{period.short_name}", "1380011PREM", @report_data, 0, @employee_deduction_results[:loan_payment])

    ####  9. AMICAL
    record_line("P/R EMPLOYEES - A/P AMICALE", "Collected from employees - amicale #{period.short_name}","2140011PREM", @report_data, 0, @employee_deduction_results[:amical])

    #### 10. Vacation Collected from EMPS (This is vac cash paid)
    record_line("P/R EMPLOYEES - A/P MISC", "Vacation collected from emp - #{period.short_name}","1140011PREM", @report_data, 0, @vacation_report_results[:cash_pay])

    #### 11. Gifts to Branch
    ### FIXME test with multiple
    ### FIXME this query is dumb
    results = Deduction.where("amount > 0 AND lower(note) like '%gift%branch%'").joins(:payslip).where("period_month = ? and period_year = ?", period.month, period.year)

    results.each do |r|
      unless (r.nil?)
        gift_amount = r.amount
        # Gift
        record_line("F/O - GIFT INC (CAMEROON)", "#{period.short_name} - gift from #{r.payslip.employee.full_name}","421001FIN17", @report_data, 0, gift_amount)
        # 1%
        one_percent = (gift_amount * 0.01).floor
        record_line("F/O - GIFT INC (CAMEROON)", "#{period.short_name} - gift from #{r.payslip.employee.full_name} 1% Int'l assmt", "421001FIN17", @report_data, one_percent, 0)
        # 30%
        zero_thirty_percent = (one_percent * 0.3).floor
        record_line("F/O - PMC CLEARING HOUSE TRANSACTIONS", "1% Int'l assmt on gift from #{r.payslip.employee.full_name} Ref.#340", "193401FIN17", @report_data, 0, zero_thirty_percent)
        # 70%
        zero_seventy_percent = (one_percent * 0.7).floor
        record_line("F/O - PMC CLEARING HOUSE TRANSACTIONS", "1% Int'l assmt on gift from #{r.payslip.employee.full_name} Ref.#340", "193401FIN17", @report_data, 0, zero_seventy_percent)
      end
    end

    #### 12. Payroll Paid (Cash out the window)
    record_line("P/R EMPLOYEES - A/R MISC", "Payroll #{period.short_name} - Cash Pay", "1140011PREM", @report_data, 0, @employee_deduction_results[:net_pay])

    #### 13-16 Taxes Collected From Employees (Other Taxes, CNPS, CF, and AV)
    total_cnps_collected = total_cf_collected = total_crtv_collected = total_common_collected = total_cac_collected = total_prop_collected = 0
    results = DipesInternalReport.new(period: period.to_s).results.hashes
    results.each do |r|
      total_cac_collected += r[:cac].to_i
      total_cnps_collected += r[:cnps].to_i
      total_cf_collected += r[:credit_foncier].to_i
      total_crtv_collected += r[:audio_visual].to_i
      total_common_collected += r[:tax_common].to_i
      total_prop_collected += r[:tax_prop].to_i
    end

    total_tax = (total_cac_collected + total_common_collected + total_prop_collected)
    record_line("P/R EMPLOYEES - A/P TAXES", "Collected from employees - #{period.short_name} - (cac + comm + prop)", "2340011PREM", @report_data, 0, total_tax)
    record_line("P/R EMPLOYEES - A/P CNPS", "Collected from employees - #{period.short_name}", "2341011PREM", @report_data, 0, total_cnps_collected)
    record_line("P/R EMPLOYEES - A/P TAXES", "Credit Foncier frm employees - #{period.short_name}", "2340011PREM", @report_data, 0, total_cf_collected)
    record_line("P/R EMPLOYEES - A/P TAXES", "#{period.short_name} CRTV collected from employees", "2340011PREM", @report_data, 0, total_crtv_collected)

    # 17. SSSLP Payments collected from employees
    results = Deduction.where("amount > 0").where("deduction_type = ?", Charge.charge_types[:other]).
        where("note = 'SSSLP'").joins(:payslip).
          where("period_month = ? and period_year = ?", period.month, period.year)

    results.each do |r|
      record_line("SIL Staff Savings & Loan Program", "Loan pmt - #{r.payslip.employee.full_name.capitalize} #{period.short_name}", "215008SSSLP", @report_data, 0, r.amount)
    end

    # 18. Other deductions not used elsewhere. (loan payments to Cawley, etc.)
    # Present them so they can be dealt with (and make the columns add up)
    # TODO: should have a list of deductions and remove items from it as they are presented on this table. (a refactor for another day)
    results = Deduction.where("amount > 0 AND deduction_type = ? AND note not in (?) AND note not like ?",
        Charge.charge_types[:other], ['Loan Payment','amical','SSSLP'], "%ift%ranch%").
          joins(:payslip).where("period_month = ? and period_year = ?", period.month, period.year)

    results.each do |r|
      record_line("Unsorted Deduction for #{r.payslip.employee.full_name}", "#{r.note} - Need to find acct # - #{period.short_name}","XXXXXXXPREM", @report_data, 0, r.amount)
    end

    return @report_data
  end

  private

  def record_line(dept_name, dept_note, dept_account, report_data, debit_amt, credit_amt)
      line_item = {}

      line_item[:dept_name] = dept_name
      line_item[:dept_account] = dept_account
      line_item[:dept_note] = dept_note

      line_item[:debit] = debit_amt
      line_item[:credit] = credit_amt

      report_data.push(line_item)
  end

  def find_results_from_report(class_obj, period, requested_vars)
    report_obj = Object.const_get(class_obj).new(period: period.to_s)

    var_results = {}

    results = report_obj.results.hashes
    results.each do |r|
      requested_vars.each do |v|
        var_results[v] = 0 unless var_results[v]
        var_results[v] += r[v].to_f
      end
    end

    var_results
  end

end
