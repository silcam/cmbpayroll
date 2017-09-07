class PayslipsController < ApplicationController

  def index
    @employees = Employee.all
  end

  def show
    @payslip = Payslip.find(params[:id])
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

    redirect_to payslip_url(@payslip)

  end

end
