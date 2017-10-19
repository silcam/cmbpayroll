class ChildrenController < ApplicationController
  before_action :set_child, only: [:show, :edit, :update, :destroy]
  before_action :set_employee, only: [:index, :new, :create]

  def index
    authorize! :read, @employee

    @employee = Employee.find(params[:employee_id])
    @children = @employee.children.all
  end

  def show
    authorize! :read, @child
  end

  def new
    authorize! :create, Child

    @child = Child.new_with_person(parent: @employee.person)
  end

  def edit
    authorize! :update, Child
  end

  def create
    authorize! :create, Child

    @child = Child.new_with_person({parent: @employee.person}.merge(child_params))

    if @child.save
      redirect_to employee_children_url(@employee)
    else
      render :new
    end
  end

  def update
    authorize! :update, Child

    if @child.update(child_params)
      redirect_to employee_children_url(@employee)
    else
      render :edit
    end
  end

  def destroy
    authorize! :destroy, Child

    @child.destroy
    redirect_to employee_children_url(@employee)
  end

  private

  def set_child
    @child = Child.find(params[:id])
    @employee = @child.parent.employee
  end

  def set_employee
    @employee = Employee.find params[:employee_id]
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def child_params
    params.require(:child).permit(:first_name, :last_name, :birth_date, :is_student, :employee_id)
  end
end
