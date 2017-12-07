class ChargesController < ApplicationController
  before_action :set_employee, only: [:index, :new, :create]

  def index
    # if can see employee, can see her charges
    authorize! :read, @employee

    @period = get_params_period(LastPostedPeriod.current)
    @charges = @employee.charges.for_period @period
  end

  def new
    authorize! :create, Charge

    @charge = Charge.new
  end

  def create
    authorize! :create, Charge

    @charge = @employee.charges.new(charge_params)
    if @charge.save
      redirect_to employee_charges_path @employee
    else
      render :new
    end
  end

  def destroy
    authorize! :destroy, Charge

    @charge = Charge.find params[:id]
    @charge.destroy
    redirect_to employee_charges_path @charge.employee
  end

  private

  def charge_params
    set_note
    params.require(:charge).permit(:amount, :note, :date)
  end

  def set_note
    std_note = StandardChargeNote.find_by id: params[:standard_charge_note_id]
    unless std_note.nil?
      params[:charge][:note] = std_note.note
    end
  end

  def set_employee
    @employee = Employee.find params[:employee_id]
  end
end
