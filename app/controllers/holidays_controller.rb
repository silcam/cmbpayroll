class HolidaysController < ApplicationController

  def index
    prepare_index
    @holiday = Holiday.new
  end

  def create
    @holiday = Holiday.new holiday_params
    if @holiday.save
      redirect_to holidays_path(year: @holiday.date.year)
    else
      prepare_index
      render :index
    end
  end

  def generate
    @year = params[:year]
    Holiday.generate @year
    redirect_to holidays_path
  end

  def edit
    prepare_index
    @holiday = Holiday.find params[:id]
    render :index
  end

  def update
    @holiday = Holiday.find params[:id]
    if @holiday.save
      redirect_to holidays_path(year: @holiday.date.year)
    else
      prepare_index
      render :index
    end
  end

  def destroy
    @holiday = Holiday.find(params[:id])
    @holiday.destroy
    redirect_to holidays_path(year: @holiday.date.year)
  end

  private
  def prepare_index
    @year = params[:year] ? params[:year].to_i : Date.today.year
    @holidays = Holiday.for_year @year
  end

  def holiday_params
    params[:holiday]['observed(1i)'] = params[:holiday]['date(1i)']
    params[:holiday]['bridge(1i)'] = params[:holiday]['date(1i)']
    params.require(:holiday).permit(:name, :date, :observed, :bridge)
  end
end
