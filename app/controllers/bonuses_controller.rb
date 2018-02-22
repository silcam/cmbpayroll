class BonusesController < ApplicationController
  before_action :set_bonus, only: [:show, :edit, :update, :destroy]
  before_action :set_employee, only: [:index, :new, :assign, :unassign]

  def index
    authorize! :read, Bonus

    @bonuses = Bonus.all
    if (@employee)
      render 'list_possible'
    end
  end

  def show
    authorize! :read, Bonus
  end

  def assign
    authorize! :update, Bonus

    bonuses_to_assign_hash = params[:bonus]
    Bonus.assign_to_employee(@employee, bonuses_to_assign_hash)

    redirect_to employee_url(@employee)
  end

  def unassign
    authorize! :update, Bonus

    bonus = Bonus.find(params[:bonus][:b])
    @employee.bonuses.delete(bonus)

    redirect_to employee_url(@employee)
  end

  def new
    authorize! :create, Bonus

    @bonus = Bonus.new
    if (@employee)
      @bonus.employees << @employee
      render 'new_for_employee'
    else
      render 'new'
    end
  end

  def edit
    authorize! :update, Bonus
  end

  def create
    authorize! :create, Bonus

    @bonus = Bonus.new(bonus_params)

    if @bonus.save
      redirect_to @bonus, notice: 'Bonus was successfully created.'
    else
      render :new
    end
  end

  def update
    authorize! :update, Bonus

    if @bonus.update(bonus_params)
      redirect_to @bonus, notice: 'Bonus was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    authorize! :destroy, Bonus

    @bonus.destroy
    redirect_to bonuses_url, notice: 'Bonus was successfully destroyed.'
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_bonus
      @bonus = Bonus.find(params[:id])
    end

    def set_employee
      @employee = Employee.find(params[:employee_id]) if params[:employee_id]
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def bonus_params
      params.require(:bonus).permit(
          :name,
          :quantity,
          :bonus_type,
          :maximum,
          :comment,
          :ext_quantity,
          :use_caisse
      )
    end
end
