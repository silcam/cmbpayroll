class ReportsController < ApplicationController
  before_action :set_params, only: [:index, :show]

  self.responder = Dossier::XXCustomResponder

  respond_to :html, :json, :csv, :xls, :txt

  NUMBER_OF_MONTHS_SHOWN=24
  REPORTS = {
    'dipes_text' => {
      name: "DIPES Report (Text)",
      instance: Proc.new{|p| DipesReport.new()}
    },
    'dept_charge' => {
      name: "Department Charge Report",
      instance: Proc.new{|p| DepartmentChargeReport.new()}
    },
    'dipe' => {
      name: "(TODO) DIPES Report",
      instance: Proc.new{|p| DipesReport.new()}
    },
    'dipe_govt' => {
      name: "(TODO) DIPES Government Report",
      instance: Proc.new{|p| DipesReport.new()}
    },
    'dipe_internet' => {
      name: "(TODO) DIPES Internal Report",
      instance: Proc.new{|p| DipesReport.new()}
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
    'transaction_by_name' => {
      name: "Transaction Audit Report - By Name",
      instance: Proc.new{|p| TransactionReportByName.new()}
    },
    'transaction_by_type' => {
      name: "Transaction Audit Report - By Type",
      instance: Proc.new{|p| TransactionReportByType.new()}
    },
    'cnps' => {
      name: "CNPS Report",
      instance: Proc.new{|p| CnpsReport.new()}
    },
    'employee_vacation' => {
      name: "Employee Vacation Report",
      instance: Proc.new{|p| EmployeeVacationReport.new()}
    },
    'employee_advance_loan' => {
      name: "Employee Advance and Loan Report",
      instance: Proc.new{|p| EmployeeAdvanceLoanReport.new()}
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
