class SupervisorsController < ApplicationController

  def index
    authorize! :read, Supervisor

    @supervisors = Supervisor.all.includes(:employees)
  end

  def new
    authorize! :create, Supervisor

    @supervisor = Supervisor.new
  end

  def create
    authorize! :create, Supervisor

    @supervisor = Supervisor.new supervisor_params
    if @supervisor.save
      follow_redirect supervisors_path
    else
      render :new
    end
  end

  def edit
    @supervisor = Supervisor.find params[:id]
    authorize! :update, @supervisor
  end

  def update
    @supervisor = Supervisor.find params[:id]
    authorize! :update, @supervisor
    if @supervisor.update supervisor_params
      follow_redirect supervisors_path
    else
      render :edit
    end
  end

  def destroy
    authorize! :destroy, Supervisor

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
