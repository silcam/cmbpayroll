require 'payslip_generator'

class PayslipsController < ApplicationController
  include PayslipGenerator

  before_action :set_employee, only: [ :index ]

  def index
    if (@employee)
      authorize! :read, @employee

      @employee_payslips = @employee.payslips.order(period_year: :desc, period_month: :desc)

      # show history for single employee
      render "employee_history"
    else
      authorize! :update, Payslip

      @employees = Employee.currently_paid
    end
  end

  def show
    # TODO: cleanup and fix routes to make this not necessary
    if (params[:id] == "process" || params[:id] == "process_complete" ||
        params[:id] == "process_all" || params[:id] == "post_period")
      redirect_to payslips_url()
    else
      @payslip = Payslip.find(params[:id])
      authorize! :read, @payslip

      respond_to do |format|
        format.html
        format.pdf { pdf_generator(@payslip) }
      end
    end
  end

  def process_employee
    authorize! :update, Payslip

    if (params[:employee].blank? || params[:employee][:id].blank?)
      @employees = Employee.currently_paid
      flash.now[:alert] = I18n.t(:You_must_select)
      render "index"
    else
      @employee = Employee.find(params[:employee][:id])
      @period = LastPostedPeriod.current
    end
  end

  def process_nonrfis_employees
    authorize! :update, Payslip
    process_subset(Employee.nonrfis())
  end

  def process_rfis_employees
    authorize! :update, Payslip
    process_subset(Employee.rfis())
  end

  def process_bro_employees
    authorize! :update, Payslip
    process_subset(Employee.bro())
  end

  def process_gnro_employees
    authorize! :update, Payslip
    process_subset(Employee.gnro())
  end

  def process_av_employees
    authorize! :update, Payslip
    process_subset(Employee.aviation())
  end

  def process_all_employees
    authorize! :update, Payslip
    process_subset(Employee.all())
  end

  def process_employee_complete
    authorize! :update, Payslip

    employee_id = params[:employee][:id].to_i
    period_year = params[:period][:year].to_i
    period_month = params[:period][:month].to_i

    @period = Period.new(period_year, period_month)
    @employee = Employee.find(employee_id)
    @payslip = nil

    if (params[:advance])
      @payslip = Payslip.process_with_advance(@employee, @period)
    else
      @payslip = Payslip.process(@employee, @period)
    end

    if (@payslip.errors.size > 0)
      render 'process_employee'
    else
      redirect_to payslip_url(@payslip, format: "pdf")
    end
  end

  def post_period
    authorize! :update, Payslip

    @payslips = Payslip.process_all Employee.all(), LastPostedPeriod.current
    if @payslips.any?{ |payslip| payslip.errors.any? }
      @post_period_success = false
    else
      @post_period_success = true
      LastPostedPeriod.post_current
    end
    render :process_all_employees
  end

  def unpost_period
    authorize! :update, Payslip

    LastPostedPeriod.unpost
    redirect_to payslips_path
  end

  def print_multi
    authorize! :update, Payslip

    @slips = flash[:processed_payslips]
    flash[:processed_payslips] = @slips

    pdf_generate_multi(@slips, download = true)
  end

  private

  def process_subset(employees)
    @payslips = Payslip.process_all(employees, LastPostedPeriod.current)

    slips = []
    @payslips.each do |p|
      slips.push(p.id)
    end
    flash[:processed_payslips] = slips

    render 'process_all_employees'
  end

  def set_employee
    @employee = Employee.find(params[:employee_id]) if params[:employee_id]
  end

end
