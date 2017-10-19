class AdminController < ApplicationController

  def index
    authorize! :read, AdminController
  end

  def manage_variables
    authorize! :read, AdminController
  end

  def manage_wages
    authorize! :read, Wage

    @wages = Wage.order(category: :asc).order(echelonalt: :asc)
  end

  def manage_wage_show
    authorize! :update, Wage

    category = params[:category]
    echelon = params[:echelon]
    echelonalt = params[:echelonalt]

    @wage = Wage.find_by(category: category, echelon: echelon, echelonalt: echelonalt)
  end

  def manage_wage_update
    authorize! :update, Wage

    category = params[:category]
    echelon = params[:echelon]
    echelonalt = params[:echelonalt]

    @wage = Wage.find_by(category: category, echelon: echelon, echelonalt: echelonalt)
    if @wage.update wage_params
      redirect_to admin_manage_wages_path, notice: 'Wage was successfully updated.'
    else
      render "manage_wage_show"
    end
  end

  private

  def wage_params
    params.require(:wage).permit(:basewage, :basewageb, :basewagec, :basewaged, :basewagee)
  end

end
