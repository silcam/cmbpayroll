class VacationsController < ApplicationController

  before_action :set_employee, only: [:index, :new]

  def index
    unless @employee
      @period_vacations = Vacation.period_vacations
      @upcoming_vacations = Vacation.upcoming_vacations
    end
  end

  def new
    @vacation = Vacation.new
    @vacation.employee = @employee if @employee
  end

  def create
    @vacation = Vacation.new vacation_params
    if !params[:confirm_delete_work_hours] and @vacation.overlaps_work_hours?
      render 'overlap_alert'
    elsif @vacation.save
      follow_redirect vacations_path
    else
      render :new
    end
  end

  private

  def vacation_params
    params.require(:vacation).permit(:employee_id, 'start_date(1i)', 'start_date(2i)',
                                     'start_date(3i)', 'end_date(1i)', 'end_date(2i)',
                                     'end_date(3i)')
  end

  def set_employee
    @employee = params[:employee_id] if params[:employee_id]
  end

end
