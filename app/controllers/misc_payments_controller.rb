class MiscPaymentsController < ApplicationController

  before_action :set_employee, only: [:index, :new, :create]
  before_action :set_misc_payment, only: [:destroy]

  def index
    if @employee
      authorize! :read, @employee

      @misc_payments = @employee.misc_payments
      render 'index_for_employee'
    else
      @period = get_params_period(LastPostedPeriod.current)
      @misc_payments = MiscPayment.readable_by(MiscPayment.for_period(@period), current_user)
    end
  end

  def new
    @misc_payment = MiscPayment.new
    authorize! :create, @misc_payment
    if @employee
      render 'new_for_employee'
    else
      @employees = employees_for_mass_payment
      render 'new'
    end
  end

  def create
    if @employee
      @misc_payment = @employee.misc_payments.new(misc_payment_params)
      authorize! :create, @misc_payment
      if @misc_payment.save
        redirect_to employee_misc_payments_path(@employee)
      else
        render 'new_for_employee'
      end
    else
      @misc_payment = Employee.new.misc_payments.new(misc_payment_params)
      if @misc_payment.valid?
        params[:employees].each do |employee_id|
          Employee.find(employee_id).misc_payments.create(misc_payment_params)
        end
        redirect_to misc_payments_path
      else
        @employees = employees_for_mass_payment
        render 'new'
      end
    end
  end

  def destroy
    authorize! :destroy, @misc_payment
    @misc_payment.destroy
    redirect_to employee_misc_payments_path(@employee)
  end

  private

  def employees_for_mass_payment
    Employee.all.unscope(:order).order("employment_status, people.last_name, people.first_name")
  end

  def set_employee
    @employee = Employee.find(params[:employee_id]) if params[:employee_id]
  end

  def set_misc_payment
    @misc_payment = MiscPayment.find params[:id]
    @employee = @misc_payment.employee
  end

  def misc_payment_params
    params.require(:misc_payment).permit(:amount, :date, :note, :before_tax)
  end
end
