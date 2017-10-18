class BonusesController < EPSController
  before_action :set_bonus, only: [:show, :edit, :update, :destroy]
  before_action :set_employee, only: [:index, :new, :assign, :unassign]

  rescue_from "AccessGranted::AccessDenied" do |exception|
    redirect_to root_path, alert: "You cannot perform this action."
  end

  # GET /bonuses
  # GET /bonuses.json
  def index
    authorize! :read, Bonus

    @bonuses = Bonus.all
    if (@employee)
      render 'list_possible'
    end
  end

  # GET /bonuses/1
  # GET /bonuses/1.json
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

  # GET /bonuses/new
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

  # GET /bonuses/1/edit
  def edit
    authorize! :update, Bonus
  end

  # POST /bonuses
  # POST /bonuses.json
  def create
    authorize! :create, Bonus

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
    authorize! :update, Bonus

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
    authorize! :destroy, Bonus

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
