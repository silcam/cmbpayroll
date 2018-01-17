  top_of_page = pdf.cursor

  pdf.bounding_box([0, top_of_page], :width => 180, :height => above_table) do
    pdf.text "REPUBLIQUE DU CAMEROUN"
    pdf.text "Document d'information sur les personnel employe DIPE"
  end

  pdf.bounding_box([250, top_of_page], :width => 250, :height => above_table) do
    pdf.text "Nom du raison sociale: SIL", :align => :center
    pdf.text "Adresse: B.P. 1299  Ville: Yaounde", :align => :center
    pdf.text "Quartier: NDAMVOUT  Telephone 22.30.39.48", :align => :center
  end

  pdf.bounding_box([560, top_of_page], :width => 200, :height => above_table, :align => :center) do
    pdf.text "No. DIPE/CLE 34074-N  Feuille No. 2"
    pdf.text "No. Contribuable: 5087501-B"
    pdf.text "Reg. CNPS: 1"
    pdf.text "Mois: #{@report.report_month}   An: #{@report.year}"
  end

  # HEADER Columns
  top_of_table = pdf.cursor

  (0..13).each do |x|
    if (w_val_colspans[x-1] > 0)

      pdf.bounding_box([x_val_col[x], top_of_table - hhead1], :width => w_val_col[x], :height => hhead2) do
        pdf.indent 4 do
          pdf.text "\n"
          pdf.text row_2_text[x]
        end
        pdf.stroke_bounds
      end

      next
    end
    width = w_val_col[x]
    height = hheadfull
    if (w_val_colspans[x] > 0)
      height = hhead1
      width = w_val_colspans[x]

      pdf.bounding_box([x_val_col[x], top_of_table - hhead1], :width => w_val_col[x], :height => hhead2) do
        pdf.indent 4 do
          pdf.text "\n"
          pdf.text row_2_text[x]
        end
        pdf.stroke_bounds
      end

    end
    pdf.bounding_box([x_val_col[x], top_of_table], :width => width, :height => height) do
      pdf.indent 4 do
        pdf.text "\n"
        pdf.text row_1_text[x]
      end
      pdf.stroke_bounds
    end
  end


