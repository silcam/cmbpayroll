class PayslipCorrectionsController < ApplicationController

  before_action :authorize

  def index
    @corrections = PayslipCorrection.current
  end

  def new
    if params[:payslip]
      @employee = Employee.find params[:payslip][:employee_id]
      @correction = PayslipCorrection.new
      render 'new'
    else
      render 'employee_picker'
    end
  end

  def create
    @correction = PayslipCorrection.new payslip_correction_params
    if @correction.save
      redirect_to payslip_corrections_path
    else
      @employee = Employee.find params[:payslip_correction][:employee_id]
      render :new
    end
  end

  def edit
    @correction = PayslipCorrection.find params[:id]
    @employee = @correction.employee
  end

  def update
    @correction = PayslipCorrection.find params[:id]
    if @correction.update payslip_correction_params
      redirect_to payslip_corrections_path
    else
      @employee = @correction.employee
      render :edit
    end
  end

  def destroy
    @correction = PayslipCorrection.find params[:id]
    @correction.destroy
    redirect_to payslip_corrections_path
  end

  private

  def authorize
    authorize! :update, Payslip
  end

  def payslip_correction_params
    if params[:payslip_correction][:cfa_credit] == 'Debit'
      params[:payslip_correction][:cfa] = params[:payslip_correction][:cfa].to_i * -1
    end
    if params[:payslip_correction][:vacation_days_credit] == 'Debit'
      params[:payslip_correction][:vacation_days] = params[:payslip_correction][:vacation_days].to_f * -1
    end
    params.require(:payslip_correction).permit(:payslip_id, :cfa, :vacation_days, :note)
  end

end
