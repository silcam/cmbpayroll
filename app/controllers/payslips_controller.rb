class PayslipsController < ApplicationController

  before_action :set_employee, only: [ :index ]

  def index
    if (@employee)
      # show history for single employee
      render "employee_history"
    else
      # show other stuff
      @employees = Employee.all
    end
  end

  def show
    # TODO: cleanup and fix routes to make this
    # not necessary
    if (params[:id] == "process" || params[:id] == "process_complete" || params[:id] == "process_all")
      redirect_to payslips_url()
    else
      @payslip = Payslip.find(params[:id])
    end
  end

  def process_employee
    @period = LastPostedPeriod.current
  end

  def process_all_employees
    @period = LastPostedPeriod.current
    @payslips = Payslip.process_all(LastPostedPeriod.current)
  end

  def process_employee_complete
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

    unless (@payslip.valid?)
      render 'process_employee'
    else
      redirect_to payslip_url(@payslip)
    end
  end

  def post_period
    @payslips = Payslip.process_all LastPostedPeriod.current
    if @payslips.any?{ |payslip| payslip.errors.any? }
      @post_period_success = false
    else
      @post_period_success = true
      LastPostedPeriod.post_current
    end
    render :process_all_employees
  end

  def unpost_period
    LastPostedPeriod.unpost
    redirect_to payslips_path
  end

  private

  def set_employee
    @employee = Employee.find(params[:employee_id]) if params[:employee_id]
  end

end
