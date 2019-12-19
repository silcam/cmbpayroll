class AdminController < ApplicationController

  respond_to :html, :json

  def index
    authorize! :read, AdminController
  end

  def manage_variables
    authorize! :read, AdminController
  end

  def manage_wages
    authorize! :read, Wage

    @wages = Wage.order(category: :asc).order(echelonalt: :asc)
  end

  def manage_wage_show
    authorize! :update, Wage

    category = params[:category]
    echelon = params[:echelon]
    echelonalt = params[:echelonalt]

    @wage = Wage.find_by(category: category, echelon: echelon, echelonalt: echelonalt)
  end

  def manage_wage_update
    authorize! :update, Wage

    category = params[:category]
    echelon = params[:echelon]
    echelonalt = params[:echelonalt]

    @wage = Wage.find_by(category: category, echelon: echelon, echelonalt: echelonalt)
    if @wage.update wage_params
      redirect_to admin_manage_wages_path, notice: 'Wage was successfully updated.'
    else
      render "manage_wage_show"
    end
  end

  def timesheet
    authorize! :read, AdminController

    @periods = []
    @current = Period.current()
    period = @current.next.next
    @employees = Employee.currently_paid()

    (0..12).each do
      @periods << period
      period = period.previous
    end
  end

  def timesheets
    authorize! :read, AdminController

    @today = Date.today

    period_param = params[:period]
    @selected_employees = params[:employees]

    if @selected_employees.nil?
      redirect_to generate_timesheets_path, :notice => t(:You_must_select_one)
      return
    end

    if period_param.nil? || period_param.length == 0
      redirect_to generate_timesheets_path, :notice => t(:You_must_a_period)
      return
    end

    begin
      period_year, period_month = period_param.split('-')
      period = Period.new(period_year.to_i, period_month.to_i)
    rescue
      period = Period.current
    end

    @start_date = period.start
    @end_date = period.finish

    @announcement = params[:timesheet][:announcement]
    @filename = 'eps-timesheet.pdf'
  end

  def estimate_pay
    authorize! :read, AdminController
  end

  def estimate_pay_process
    authorize! :read, AdminController

    estimate_to_use = params[:estimate]
    @result = Payslip.compute_wage_from_departmental_charge(estimate_to_use.to_i)

    respond_to do |format|
      format.json do
        render json: @result, :content_type => "text/json"
      end
    end
  end

  private

  def wage_params
    params.require(:wage).permit(:basewage, :basewageb, :basewagec, :basewaged, :basewagee)
  end

end
