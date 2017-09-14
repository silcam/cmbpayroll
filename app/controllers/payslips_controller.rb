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
    if (params[:id] == "process" || params[:id] == "process_complete")
      redirect_to payslips_url()
    else
      @payslip = Payslip.find(params[:id])
    end
  end

  def process_employee

  end

  def process_employee_complete

    employee_id = params[:employee][:id].to_i
    period_year = params[:period][:year].to_i
    period_month = params[:period][:month].to_i

    @period = Period.new(period_year, period_month)
    @employee = Employee.find(employee_id)

    @payslip = Payslip.process(@employee, @period)

    unless (@payslip.valid?)
      render 'process_employee'
    else
      redirect_to payslip_url(@payslip)
    end

  end

  def set_employee
    @employee = Employee.find(params[:employee_id]) if params[:employee_id]
  end

end
