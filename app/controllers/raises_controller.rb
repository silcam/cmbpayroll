class RaisesController < ApplicationController
  before_action :set_employee, only: [:new, :create]

  def new
    @raise = Raise.new_for @employee
  end

  def create
    @raise = @employee.raises.new(raise_params)
    @employee.assign_attributes raise_params
    if @raise.valid? and @employee.valid?
      Raise.transaction do
        @raise.save
        @employee.save
      end
      redirect_to employee_path(@employee)
    else
      render 'new'
    end
  end

  private

  def set_employee
    @employee = Employee.find params[:employee_id]
    authorize! :update, @employee
  end

  def raise_params
    params.require(:raise).permit(:category, :echelon, :wage_scale, :wage_period, :wage)
  end

end
