class SeedStandardChargeNotes < ActiveRecord::Migration[5.1]
  
  SEEDS = %w[MTN Photocopy Electricity Water Telephone]
  
  def up
    SEEDS.each do |note|
      StandardChargeNote.create!(note: note)
    end
  end

  def down
    SEEDS.each do |note|
      StandardChargeNote.find_by(note: note).try(:destroy)
    end
  end
end
