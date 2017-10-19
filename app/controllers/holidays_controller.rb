class HolidaysController < ApplicationController

  def index
    authorize! :read, Holiday

    prepare_index
    @holiday = Holiday.new
  end

  def create
    authorize! :create, Holiday

    @holiday = Holiday.new holiday_params
    if @holiday.save
      redirect_to holidays_path(year: @holiday.date.year)
    else
      prepare_index
      render :index
    end
  end

  def generate
    authorize! :create, Holiday

    @year = params[:year].to_i
    Holiday.generate @year
    redirect_to holidays_path(year: @year)
  end

  def edit
    authorize! :update, Holiday

    @holiday = Holiday.find params[:id]
    prepare_index @holiday.date.year
    render :index
  end

  def update
    authorize! :update, Holiday

    @holiday = Holiday.find params[:id]
    if @holiday.update holiday_params
      redirect_to holidays_path(year: @holiday.date.year)
    else
      prepare_index @holiday.date.year
      render :index
    end
  end

  def destroy
    authorize! :destroy, Holiday

    @holiday = Holiday.find(params[:id])
    @holiday.destroy
    redirect_to holidays_path(year: @holiday.date.year)
  end

  private
  def prepare_index(year = nil)
    if year
      @year = year
    else
      @year = params[:year] ? params[:year].to_i : Date.today.year
    end
    @holidays = Holiday.for_year @year
  end

  def holiday_params
    params[:holiday]['observed(1i)'] = params[:holiday]['date(1i)']
    params[:holiday]['bridge(1i)'] = params[:holiday]['date(1i)']
    params.require(:holiday).permit(:name, :date, :observed, :bridge)
  end
end
