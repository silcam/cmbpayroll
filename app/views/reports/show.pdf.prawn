prawn_document(page_layout: :landscape) do |pdf|

  pdf.font_size 9

  max_rows_on_a_page = 30
  padding = 10

  hhead1 = 20
  hhead2 = 30
  hheadfull = 50
  above_table = 50

  total_header_height = (hheadfull + above_table)

  row_height = 10

  x_val_col = [0,100,125,150,210,270,330,390,450,510,570,630,680,710]
  w_val_col = [100,25,25,60,60,60,60,60,60,60,60,50,30,50]
  w_val_colspans = [125,0,0,0,0,0,120,0,0,0,0,0,0,0]

  row_1_text = [
    "1",
    "",
    "2\nNB Jour",
    "3\nSalaire Brut",
    "4\nElements Exception",
    "5\nSalaire Taxable",
    "Salaire Cotisable CNPS",
    "",
    "8\nRetenue Taxe Prop",
    "9\nRetenue Srt Prog",
    "10\nCentime Add\nCom",
    "11\nRetenue\nTaxe Com",
    "Ligne",
    "Matricule Intern",
    "Matricule CNPS"
  ]

  row_2_text = [
    "Matricule CNPS",
    "CLE",
    nil,
    nil,
    nil,
    nil,
    "6\nTotal",
    "7\nPlafonne",
    nil,
    nil,
    nil,
    nil,
    nil,
    nil
  ]

  col_sums = [ 0,0,0,0,0,0,0,0,0,0,0,0,0 ]

  num_records = @report.results.body.size
  data_row = pdf.cursor

  # HEADER HERE
  render "header", :pdf => pdf, :report => @report, :row_1_text => row_1_text,
      :row_2_text => row_2_text, :x_val_col => x_val_col, :w_val_col => w_val_col,
        :w_val_colspans => w_val_colspans, :hheadfull => hheadfull, :hhead1 => hhead1,
          :hhead2 => hhead2, :data_row => data_row, :above_table => above_table


  # Move data rows below headers
  data_row -= total_header_height

  # Number of rows of data that can fit on a page.
  if (num_records > 30)
    height_needed = max_rows_on_a_page * row_height + row_height
  else
    height_needed = num_records * row_height
  end

  # Build out placeholder columns of the correct height for the number
  # of expected data rows.
  render  "placeholders", :pdf => pdf, :data_row => data_row, :w_val_col => w_val_col,
      :x_val_col => x_val_col, :height_needed => height_needed


  data_row -= row_height

  # Write out the data
  row_count = 0
  @report.results.body.each do |row|

    col_count = 0
    row.each do |value|

      if (col_count > 4 && col_count < 12)
        pdf.draw_text number_to_currency(value, delimiter: ' ', precision: 0, unit: ''),
            :at => [x_val_col[col_count] + padding, data_row]
        col_sums[col_count] += value.to_i
      elsif (col_count == 2)
        pdf.draw_text value.to_i, :at => [x_val_col[col_count] + padding, data_row]
      else
        pdf.draw_text value.to_s, :at => [x_val_col[col_count] + padding, data_row]
      end

      col_count += 1
    end


    row_count += 1
    data_row -= row_height

    # If we've filled the page, we need to do a few things
    # to make a new page and start over.
    if (row_count % max_rows_on_a_page == 0)

      pdf.start_new_page

      # Re-make header
      top_of_page = pdf.cursor

      # HEADER HERE on next page.
      render "header", :pdf => pdf, :row_1_text => row_1_text, :row_2_text => row_2_text,
          :x_val_col => x_val_col, :w_val_col => w_val_col, :w_val_colspans => w_val_colspans,
            :hheadfull => hheadfull, :hhead1 => hhead1, :hhead2 => hhead2,
              :data_row => data_row, :above_table => above_table

      data_row = top_of_page - total_header_height
      height_needed = ((num_records - row_count) * row_height) + row_height

      render  "placeholders", :pdf => pdf, :data_row => data_row, :w_val_col => w_val_col,
          :x_val_col => x_val_col, :height_needed => height_needed

      row_count = 0
      data_row -= row_height

    end
  end

  # Make footer.
  footer_y = data_row
  footer_height = 50

  pdf.bounding_box([x_val_col[0], footer_y], :width => (
      w_val_col[0]+w_val_col[1]+w_val_col[2]+w_val_col[3]+w_val_col[4]), :height => footer_height) do

    pdf.indent 10, 14 do
      pdf.text "\n"
      pdf.text "Totaux : ", :align => :right
      pdf.text "Rappport do DIPE precendent No : ", :align => :right
      pdf.text "Cumule : ", :align => :right
    end
    pdf.stroke_bounds
  end

  (5..11).each do |x|
    pdf.bounding_box([x_val_col[x], data_row], :width => w_val_col[x], :height => footer_height) do
      pdf.indent 10 do
        pdf.text "\n"
        pdf.text number_to_currency(col_sums[x], delimiter: ' ', precision: 0, unit: '')
        pdf.text "\n"
        pdf.text number_to_currency(col_sums[x], delimiter: ' ', precision: 0, unit: '')
      end
      pdf.stroke_bounds
    end
  end

  pdf.bounding_box([x_val_col[12], footer_y], :width => (w_val_col[12]+w_val_col[13]), :height => footer_height) do
    pdf.stroke_bounds
  end

end
