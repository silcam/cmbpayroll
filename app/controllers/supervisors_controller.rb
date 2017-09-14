class SupervisorsController < ApplicationController

  def index
    @supervisors = Supervisor.all.includes(:employees)
  end

  def new
    @supervisor = Supervisor.new
  end

  def create
    @supervisor = Supervisor.new supervisor_params
    if @supervisor.save
      follow_redirect supervisors_path
    else
      render :new
    end
  end

  def destroy
    Supervisor.find(params[:id]).destroy
    redirect_to supervisors_path
  end

  private

  def supervisor_params
    if params[:supervisor][:person_id].to_i >= 1
      permitted = [:person_id]
    else
      permitted = [:first_name, :last_name]
    end
    params.require(:supervisor).permit(permitted)
  end
end
