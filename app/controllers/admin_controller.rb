class AdminController < ApplicationController

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
    @periods = []
    @current = Period.current()
    period = @current.next.next

    (0..12).each do
      @periods << period
      period = period.previous
    end
  end

  def timesheets
    @today = Date.today

    period_param = params[:period]

    begin
      period_year, period_month = period_param.split('-')
      period = Period.new(period_year.to_i, period_month.to_i)
    rescue
      period = Period.current
    end

    @start_date = period.start
    @end_date = period.finish

    @announcement = params[:timesheet][:announcement]

    @employees = Employee.currently_paid()

    @filename = 'eps-timesheet.pdf'
  end

  private

  def wage_params
    params.require(:wage).permit(:basewage, :basewageb, :basewagec, :basewaged, :basewagee)
  end

end
