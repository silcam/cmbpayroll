class TransactionsController < ApplicationController
  before_action :set_employee, only: [:new, :create]

  def index

  end

  def new
    @transaction = Transaction.new
  end

  def create

  end

  private

  def transaction_params

  end

  def set_employee
    @employee = Employee.find params[:employee_id]
  end
end
