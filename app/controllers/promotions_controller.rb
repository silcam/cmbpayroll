class PromotionsController < ApplicationController
  before_action :set_employee, only: [:new, :create]

  def new
    @promotion = Promotion.new_for @employee
  end

  def create
    @promotion = @employee.promotions.new(promotion_params)
    @employee.assign_attributes promotion_params
    if @promotion.valid? and @employee.valid?
      Promotion.transaction do
        @promotion.save
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

  def promotion_params
    params.require(:promotion).permit(:category, :echelon, :wage_scale, :wage_period, :wage)
  end

end
