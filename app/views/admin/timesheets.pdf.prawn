@@box_width = 100
@@box_height = 55
@@box_gutter = 10
@@half_gutter = 5

prawn_document(page_layout: :landscape) do |pdf|

  holidays_hash = Holiday.days_hash(@start_date, @end_date)

  @selected_employees.each do |eid|

    employee = Employee.find(eid)

    # Header
    pdf.text "SIL EMPLOYEE TIMESHEET", :align => :center, :style => :bold
    pdf.text_box("#{@today.strftime('%A %-d %B %Y')}. Employee: #{employee.first_name} #{employee.last_name} (#{employee.id}), Supervisor: #{employee&.supervisor&.first_name} #{employee&.supervisor&.last_name}", :at => [0,pdf.cursor], :size => 9)
    pdf.move_down @@box_gutter
    pdf.horizontal_rule

    # What Period This is for
    pdf.move_down 5
    pdf.text "Period from #{@start_date.strftime('%A %-d %B %Y')} to #{@end_date.strftime('%A %-d %B %Y')}",
        :align => :center, :size => 9

    pdf.move_down 15

    # Calendar Display
    right_offset = 0
    y_offset = pdf.cursor

    if (@start_date.wday > 1 || @start_date.wday == 0)
      # placeholders so the first of the month is in the right column
      start = 1

      (1..7).each do |d|
        if (start == @start_date.wday || start == 7)
          break
        else
          right_offset += (@@box_width + @@box_gutter)
          start += 1
        end
      end
    end

    (@start_date..@end_date).each do |dt|
      right_adj = @@box_width + @@box_gutter

      day_hash = holidays_hash[dt]

      pdf.bounding_box([right_offset, y_offset], :width => @@box_width, :height => @@box_height) do
        pdf.font("Helvetica", :size => 9) do
          pdf.indent 8 do
            pdf.draw_text("#{dt.strftime('%a %b %d')}", :at => [0, (pdf.bounds.top - 12)], :style => :bold)
            pdf.draw_text("#{day_hash[:holiday].slice(0,20)}", :size => 8,
                :at => [0, (pdf.bounds.top - 24)], :style => :italic) if day_hash
            pdf.draw_text("__ Excused Absence", :size => 8, :at => [0, (pdf.bounds.bottom + 5)])
          end
        end

        pdf.stroke_bounds
      end

      right_offset += right_adj

      # Carriage Return
      if (dt.wday == 0)
        y_offset -= (@@box_height + @@box_gutter)
        right_offset = 0
      end
    end

    pdf.move_down 15

    pdf.font("Helvetica", :style => :bold) do
      pdf.text "Due date: #{@end_date + 1}"
    end

    pdf.move_down @@box_gutter

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
      pdf.move_down @@box_gutter
      pdf.font("Helvetica", :style => :italic, :size => 10) do
        pdf.text "Announcements: #{@announcement}"
      end
    end
  end
end
