
  # Data Placeholders
  (0..13).each do |x|
    pdf.bounding_box([x_val_col[x], data_row], :width => w_val_col[x], :height => height_needed) do
      pdf.stroke_bounds
    end
  end
