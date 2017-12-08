class ReportsController < ApplicationController
  before_action :set_params, only: [:index, :show]

  self.responder = Dossier::XXCustomResponder

  ActionController.add_renderer :pdf do |pdf, options|
    self.headers["Content-Type"] = "application/pdf"
    self.headers["Content-Disposition"] = %[attachment;filename=#{@report.to_s}.pdf]
    self.response_body = @report.render_pdf
  end

  ActionController.add_renderer :txt do |txt, options|
    self.headers["Content-Type"] = "text/plain"
    self.headers["Content-Disposition"] = %[attachment;filename=#{@report.to_s}.txt]
    self.response_body = @report.render_txt
  end

  respond_to :html, :json, :csv, :xls, :txt, :pdf

  NUMBER_OF_MONTHS_SHOWN=24
  REPORTS = {
    'cnps' => {
      name: "CNPS Report",
      instance: Proc.new{|p| CnpsReport.new()}
    },
    'dept_charge' => {
      name: "Department Charge Report",
      instance: Proc.new{|p| DepartmentChargeReport.new()}
    },
    'dipes' => {
      name: "DIPES Report (Text)",
      instance: Proc.new{|p| DipesReport.new()}
    },
    'dipes_government' => {
      name: "DIPES Government Report",
      instance: Proc.new{|p| DipesGovernmentReport.new()}
    },
    'dipe_internet' => {
      name: "DIPES Internal Report",
      instance: Proc.new{|p| DipesInternalReport.new()}
    },
    'employee_advance_loan' => {
      name: "Employee Advance and Loan Report",
      instance: Proc.new{|p| EmployeeAdvanceLoanReport.new()}
    },
    'employee_deduction' => {
      name: "Employee Deduction Report",
      instance: Proc.new{|p| EmployeeDeductionReport.new()}
    },
    'employee' => {
      name: "Employee Report",
      instance: Proc.new{|p| EmployeeReport.new()}
    },
    'employee_by_dept' => {
      name: "Employee Report - By Department",
      instance: Proc.new{|p| EmployeeByDepartmentReport.new()}
    },
    'employee_vacation' => {
      name: "Employee Vacation Report",
      instance: Proc.new{|p| EmployeeVacationReport.new()}
    },
    'pay_breakdown_all' => {
      name: "Pay Breakdown (All) Report",
      instance: Proc.new{|p| PayBreakdownAllReport.new()}
    },
    'pay_breakdown_rfis' => {
      name: "Pay Breakdown (RFIS) Report",
      instance: Proc.new{|p| PayBreakdownRfisReport.new()}
    },
    'pay_breakdown_nonrfis' => {
      name: "Pay Breakdown (Non-RFIS) Report",
      instance: Proc.new{|p| PayBreakdownNonrfisReport.new()}
    },
    'post' => {
      name: "(TODO) Post Report",
      instance: Proc.new{|p| CnpsReport.new()}
    },
    'salary_changes' => {
      name: "Salary Changes Report",
      instance: Proc.new{|p| SalaryChangesReport.new()}
    },
    'transaction_by_name' => {
      name: "Transaction Audit Report - By Name",
      instance: Proc.new{|p| TransactionReportByName.new()}
    },
    'transaction_by_type' => {
      name: "Transaction Audit Report - By Type",
      instance: Proc.new{|p| TransactionReportByType.new()}
    }
  }

  def index
    authorize! :read, ReportsController
  end

  def show
    authorize! :read, ReportsController

    if (REPORTS.has_key?(params[:report]))
      @report = REPORTS[params[:report]][:instance].call(params[:period])
      @report.set_options(params[:options].to_unsafe_h() || {})
      @report_description = @report.report_description

      respond_with(@report)
    else
      redirect_to "/reports/", status: 302
    end
  end

  private

  def set_params
    @report_options = {}
    REPORTS.each { |k,v|
      @report_options[v[:name]] = k
    }

    @periods = {}
    period = Period.current()

    (0..NUMBER_OF_MONTHS_SHOWN).each do |x|
      @periods[period.name] = period.to_s
      period = period.previous
    end
  end

end
