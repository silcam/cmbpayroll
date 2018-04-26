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
      name: I18n.t(:Cnps_report, scope: "reports"),
      instance: Proc.new{|p| CnpsReport.new()}
    },
    'dept_charge' => {
      name: I18n.t(:Department_charge_report, scope: "reports"),
      instance: Proc.new{|p| DepartmentChargeReport.new()},
      format: :pdf
    },
    'dipes' => {
      name: I18n.t(:Dipes_report_text, scope: "reports"),
      instance: Proc.new{|p| DipesReport.new()}
    },
    'dipes_government' => {
      name: I18n.t(:Dipes_government_report, scope: "reports"),
      instance: Proc.new{|p| DipesGovernmentReport.new()},
      format: :pdf
    },
    'dipe_internal' => {
      name: I18n.t(:Dipes_internal_report, scope: "reports"),
      instance: Proc.new{|p| DipesInternalReport.new()},
      format: :pdf
    },
    'employee_advance_loan' => {
      name: I18n.t(:Employee_advance_and_loan_report, scope: "reports"),
      instance: Proc.new{|p| EmployeeAdvanceLoanReport.new()}
    },
    'employee_deduction' => {
      name: I18n.t(:Employee_deduction_report, scope: "reports"),
      instance: Proc.new{|p| EmployeeDeductionReport.new()}
    },
    'employee' => {
      name: I18n.t(:Employee_report, scope: "reports"),
      instance: Proc.new{|p| EmployeeReport.new()},
      format: :pdf
    },
    'employee_by_dept' => {
      name: I18n.t(:Employee_report_by_dept, scope: "reports"),
      instance: Proc.new{|p| EmployeeByDepartmentReport.new()}
    },
    'employee_vacation' => {
      name: I18n.t(:Employee_vacation_report, scope: "reports"),
      instance: Proc.new{|p| EmployeeVacationReport.new()}
    },
    'pay_breakdown_all' => {
      name: I18n.t(:Pay_breakdown_all_report, scope: "reports"),
      footer_rows: 1,
      instance: Proc.new{|p| PayBreakdownAllReport.new()},
      format: :pdf
    },
    'pay_breakdown_rfis' => {
      name: I18n.t(:Pay_breakdown_rfis_report, scope: "reports"),
      footer_rows: 1,
      instance: Proc.new{|p| PayBreakdownRfisReport.new()},
      format: :pdf
    },
    'pay_breakdown_nonrfis' => {
      name: I18n.t(:Pay_breakdown_non_rfis_report, scope: "reports"),
      footer_rows: 1,
      instance: Proc.new{|p| PayBreakdownNonrfisReport.new()},
      format: :pdf
    },
    'post' => {
      name: I18n.t(:Post_report, scope: "reports"),
      instance: Proc.new{|p| PostReport.new()},
      format: :pdf
    },
    'salary_changes' => {
      name: I18n.t(:Salary_changes_report, scope: "reports"),
      instance: Proc.new{|p| SalaryChangesReport.new()}
    },
    'transaction_by_name' => {
      name: I18n.t(:Transaction_audit_report_by_name, scope: "reports"),
      instance: Proc.new{|p| TransactionReportByName.new()},
      format: :pdf
    },
    'transaction_by_type' => {
      name: I18n.t(:Transaction_audit_report_by_type, scope: "reports"),
      instance: Proc.new{|p| TransactionReportByType.new()},
      format: :pdf
    }
  }

  def index
    authorize! :read, ReportsController
  end

  def show
    authorize! :read, ReportsController

    if (REPORTS.has_key?(params[:report]))
      @report = REPORTS[params[:report]][:instance].call(params[:period])
      params[:options][:footer] = REPORTS[params[:report]][:footer_rows]
      @report.set_options(params[:options].to_unsafe_h() || {})

      @report_description = @report.report_description

      if REPORTS[params[:report]][:format] == :pdf
        render @report.report_name, formats: :pdf
      else
        respond_with(@report)
      end
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
