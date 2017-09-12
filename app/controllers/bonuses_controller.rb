class BonusesController < ApplicationController
  before_action :set_bonus, only: [:show, :edit, :update, :destroy]

  # GET /bonuses
  # GET /bonuses.json
  def index
    @bonuses = Bonus.all
  end

  # GET /bonuses/1
  # GET /bonuses/1.json
  def show
  end

  # GET /bonuses/new
  def new
    @bonus = Bonus.new
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

    # Never trust parameters from the scary internet, only allow the white list through.
    def bonus_params
      params.require(:bonus).permit(:name, :quantity, :bonus_type, :comment)
    end
end
