prawn_document(page_layout: :landscape) do |pdf|

  @employees.each do |employee|

    # Header
    pdf.text_box("#{@today.strftime('%A %-d %B %Y')}", :at => [0,pdf.cursor])
    pdf.text "SIL EMPLOYEE TIMESHEET", :align => :center, :style => :bold
    pdf.text_box("Employee: #{employee.first_name} #{employee.last_name} (#{employee.id}), Supervisor: #{employee&.supervisor&.first_name} #{employee&.supervisor&.last_name}", :at => [0,pdf.cursor])
    pdf.move_down 15
    pdf.horizontal_rule

    # What Period This is for
    pdf.move_down 5
    pdf.text "Period from #{@start_date.strftime('%A %-d %B %Y')} to #{@end_date.strftime('%A %-d %B %Y')}", :align => :center

    pdf.move_down 15

    # Calendar Display
    right_offset = 0
    y_offset = pdf.cursor

    if (@start_date.wday > 0)
      # placeholders so the first of the month is in the right column
      start = 0
      while (start < @start_date.wday)
        right_offset += 110
        start += 1
      end
    end

    (@start_date..@end_date).each do |dt|
      right_adj = 100 + 10

      pdf.bounding_box([right_offset, y_offset], :width => 100, :height => 45) do
        pdf.font("Helvetica", :size => 9, :style => :bold) do
          pdf.indent 8 do
            pdf.draw_text("#{dt.strftime('%a %b %d')}", :at => [0, (pdf.bounds.top - 12)])
          end
        end

        pdf.font("Helvetica", :size => 9) do
          pdf.indent 8 do
            pdf.draw_text("__ Excused Absence", :size => 8, :at => [0, (pdf.bounds.bottom + 5)])
          end
        end

        pdf.stroke_bounds
      end

      right_offset += right_adj

      # Carriage Return
      if (dt.wday == 6)
        y_offset -= 55
        right_offset = 0
      end
    end

    pdf.move_down 15

    pdf.font("Helvetica", :style => :bold) do
      pdf.text "Due date: #{@end_date + 1}"
    end

    pdf.move_down 10

    box_y = pdf.cursor

    pdf.bounding_box([0, box_y], :width => 500, :height => 50) do
      pdf.font("Helvetica", :size => 10) do
        pdf.indent 8 do
          pdf.draw_text("Signature of Employee: ___________________________________ Date: __________________________",
              :at => [0, (pdf.bounds.top - 19)])
          pdf.draw_text("Signature of Supervisor: __________________________________ Date: __________________________",
              :at => [0, (pdf.bounds.top - 39)])
        end
      end
      pdf.stroke_bounds
    end

    pdf.bounding_box([500, box_y], :width => 260, :height => 50) do
      pdf.font("Helvetica", :size => 9, :style => :bold) do
        pdf.indent 8 do
          pdf.draw_text("Comments", :at => [0, (pdf.bounds.top - 12)])
        end
      end
      pdf.stroke_bounds
    end

    # Announcements
    unless (@announcement.nil? || @announcement.empty?)
      pdf.horizontal_rule
      pdf.move_down 10
      pdf.font("Helvetica", :style => :italic, :size => 10) do
        pdf.text "Announcements: #{@announcement}"
      end
    end

    # Don't make an empty, blank page after the last employee
    unless employee == @employees.last
      pdf.start_new_page
    end

  end

end
