class VacationsController < ApplicationController

  before_action :set_employee, only: [:index, :new]
  before_action :set_vacation, only: [:edit, :update, :destroy]

  #TODO Find a solution for why Feb 31 saves as Mar 3

  def index
    if @employee
      render 'index_for_employee'
    else
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
    unless @vacation.valid?
      render :new
      return
    end

    if deconflicted_save
      follow_redirect vacations_path
    end
  end

  def edit

  end

  def update
    @vacation.update_attributes vacation_params
    unless @vacation.valid?
      render :edit
      return
    end

    if deconflicted_save
      follow_redirect vacations_path
    end
  end

  def destroy
    @vacation.destroy
    follow_redirect vacations_path
  end

  private

  def vacation_params
    params[:vacation][:start_date] = assemble_date(params[:vacation], 'start_date')
    params[:vacation][:end_date] = assemble_date(params[:vacation], 'end_date')
    params.require(:vacation).permit(:employee_id, :start_date, :end_date)
  end

  def set_employee
    @employee = Employee.find(params[:employee_id]) if params[:employee_id]
  end

  def set_vacation
    @vacation = Vacation.find params[:id]
  end

  def deconflicted_save
    if !params[:confirm_delete_work_hours] and @vacation.overlaps_work_hours?
      render 'overlap_alert'
      return false
    end
    @vacation.save!
  end

end
