class VacationsController < ApplicationController

  before_action :set_employee, only: [:index, :new, :days_summary]
  before_action :set_vacation, only: [:edit, :update, :destroy]

  #TODO Find a solution for why Feb 31 saves as Mar 3

  def index
    if @employee
      authorize! :read, @employee

      @vacations = @employee.vacations
      render 'index_for_employee'
    else
      authorize! :admin, Employee

      @period = get_params_period
      @period_vacations = Vacation.for_period(@period)
      @upcoming_vacations = Vacation.upcoming_vacations
    end
  end

  def new
    authorize! :create, Vacation

    @vacation = Vacation.new
    if @employee
      @vacation.employee = @employee
      render 'new_for_employee'
    else
      render 'new'
    end
  end

  def create
    authorize! :create, Vacation

    @vacation = Vacation.new vacation_params
    unless @vacation.valid?
      render :new
      return
    end

    if deconflicted_save
      redirect_user
    end
  end

  def edit
    authorize! :update, Vacation

  end

  def update
    authorize! :update, Vacation

    @vacation.update_attributes vacation_params
    unless @vacation.valid?
      render :edit
      return
    end

    if deconflicted_save
      redirect_user
    end
  end

  def destroy
    authorize! :destroy, Vacation

    @vacation.destroy
    redirect_user
  end

  def days_summary
    authorize! :read, @employee

    render layout: false
  end

  private

  def vacation_params
    params.require(:vacation).permit(:employee_id, 'start_date(1i)', 'start_date(2i)',
                                     'start_date(3i)', 'end_date(1i)', 'end_date(2i)',
                                     'end_date(3i)', :start_date, :end_date)
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


  def redirect_user
    if (params[:referred_by].present?)
      redirect_to params[:referred_by]
    else
      follow_redirect vacations_path
    end
  end

end
