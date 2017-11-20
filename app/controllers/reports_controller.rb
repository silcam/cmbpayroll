class ReportsController < ApplicationController
  before_action :set_params, only: [:index, :show]

  self.responder = Dossier::XXCustomResponder

  respond_to :html, :json, :csv, :xls, :txt

  NUMBER_OF_MONTHS_SHOWN=24
  REPORTS = {
    'employee' => {
      name: "Employee Report",
      instance: Proc.new{|p| EmployeeReport.new()}
    },
    'employee_by_dept' => {
      name: "Employee Report - By Department",
      instance: Proc.new{|p| EmployeeByDepartmentReport.new()}
    },
    'cnps' => {
      name: "CNPS Report",
      instance: Proc.new{|p| CnpsReport.new()}
    },
    'employee_vacation' => {
      name: "Employee Vacation Report",
      instance: Proc.new{|p| EmployeeVacationReport.new()}
    },
    'employee_deduction' => {
      name: "Employee Deduction Report",
      instance: Proc.new{|p| EmployeeDeductionReport.new()}
    },
    'dipes' => {
      name: "DIPES Report",
      instance: Proc.new{|p| DipesReport.new()}
    },
    'dept_charges' => {
      name: "Department Charges Report",
      instance: Proc.new{|p| EmployeeReport.new()}
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
