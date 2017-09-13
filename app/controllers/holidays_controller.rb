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
    @year = params[:year].to_i
    Holiday.generate @year
    redirect_to holidays_path(year: @year)
  end

  def edit
    @holiday = Holiday.find params[:id]
    prepare_index @holiday.date.year
    render :index
  end

  def update
    @holiday = Holiday.find params[:id]
    if @holiday.update holiday_params
      redirect_to holidays_path(year: @holiday.date.year)
    else
      prepare_index @holiday.date.year
      render :index
    end
  end

  def destroy
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
