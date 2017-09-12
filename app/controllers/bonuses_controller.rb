class BonusesController < ApplicationController
  before_action :set_bonus, only: [:show, :edit, :update, :destroy]
  before_action :set_employee, only: [:index, :new, :assign, :unassign]

  # GET /bonuses
  # GET /bonuses.json
  def index
    @bonuses = Bonus.all
    if (@employee)
      render 'list_possible'
    end
  end

  # GET /bonuses/1
  # GET /bonuses/1.json
  def show
  end

  def assign
    bonuses_to_assign_hash = params[:bonus]
    Bonus.assign_to_employee(@employee, bonuses_to_assign_hash)

    redirect_to employee_url(@employee)
  end

  def unassign
    bonus = Bonus.find(params[:bonus][:b])
    @employee.bonuses.delete(bonus)

    redirect_to employee_url(@employee)
  end

  # GET /bonuses/new
  def new
    @bonus = Bonus.new
    if (@employee)
      @bonus.employees << @employee
      render 'new_for_employee'
    else
      render 'new'
    end
  end

  # GET /bonuses/1/edit
  def edit
  end

  # POST /bonuses
  # POST /bonuses.json
  def create
    @bonus = Bonus.new(bonus_params)

    respond_to do |format|
      if @bonus.save
        format.html { redirect_to @bonus, notice: 'Bonus was successfully created.' }
        format.json { render :show, status: :created, location: @bonus }
      else
        format.html { render :new }
        format.json { render json: @bonus.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /bonuses/1
  # PATCH/PUT /bonuses/1.json
  def update
    respond_to do |format|
      if @bonus.update(bonus_params)
        format.html { redirect_to @bonus, notice: 'Bonus was successfully updated.' }
        format.json { render :show, status: :ok, location: @bonus }
      else
        format.html { render :edit }
        format.json { render json: @bonus.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /bonuses/1
  # DELETE /bonuses/1.json
  def destroy
    @bonus.destroy
    respond_to do |format|
      format.html { redirect_to bonuses_url, notice: 'Bonus was successfully destroyed.' }
      format.json { head :no_content }
    end
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
      params.require(:bonus).permit(:name, :quantity, :bonus_type, :comment)
    end
end
