class StandardChargeNotesController < ApplicationController

  def index
    @standard_charge_notes = StandardChargeNote.all
  end

  def create
    StandardChargeNote.create std_chg_note_params
    redirect_to standard_charge_notes_path
  end

  def destroy
    StandardChargeNote.find(params[:id]).destroy
    redirect_to standard_charge_notes_path
  end

  private

  def std_chg_note_params
    params.require(:standard_charge_note).permit(:note)
  end
end
