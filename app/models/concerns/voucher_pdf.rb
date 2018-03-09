class VoucherPdf < CmbPayrollPdf

  attr_reader :vacation

  def initialize(vacation)
    super(:page_size => "A4", :page_layout => :landscape)
    Prawn::Font::AFM.hide_m17n_warning = true
    @vacation = vacation

    @employee = @vacation.employee
    @start_date = @vacation.start_date
    @end_date = @vacation.end_date
    @tax = @vacation.get_tax
    @union_dues = 0
    @salary_advances = 0
    @is_payslip = false

    @total_deductions = @tax.total_tax
    @total_pay = (@vacation.vacation_pay - @tax.total_tax).round
  end

  def generate
    voucher
  end

  def voucher
    font_size 8

    define_grid(:columns => 4, :rows => 4, :gutter => 25)
#    grid.show_all
#    stroke_axis

    grid([0,0],[3,1]).bounding_box do
      header
      move_down 10

      pay_table
      move_down 100

      tax_table
      move_down 20

      signature_box
    end

    grid([0,2],[2,3]).bounding_box do
      second_page
    end

    grid([3,3],[3,3]).bounding_box do
      date_and_name
    end

  end

  def pay_table
     table([
        ["Nombre de journées",
            { :content => "#{@vacation.days} à franc #{Vacation.vacation_daily_rate(@vacation.vacation_pay).round(2)}", :align => :right },
            { :content => "soit CFA", :align => :center },
            { :content => "#{@vacation.vacation_pay&.to_i}", :align => :right }]
        ],
        :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
        :width => bounds.width )
  end

  def vacation_summary_table
    table([
        [
          { :content => "CONGE ACCUMULÉ (#{@vacation.start_date} - #{@vacation.end_date} for period: #{Period.from_date(@vacation.end_date)})", :colspan => 2 }
        ],
        ["Jours utilisées ces vacances",
          { :content => "-#{@vacation.days}", :align => :right }
        ],
        ["Jusqu'aujourd'hui",
          { :content => "#{Vacation.balance(@vacation.employee, Period.from_date(@vacation.end_date))} jours", :align => :right }
        ],
        ["Derner Congé",
          { :content => "#{@vacation.start_date} - #{@vacation.end_date}", :align => :right }
        ],
    ],
    :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
    :position => :left )
  end

  def second_page
    second_page_header

    data = [
        ["<b>Salaire Net (arrondi)</b>", "", "",
        { :content => "#{Payslip.cfa_round(@total_pay)}", :align => :right }]
    ]

    data << [
        "<b>MONTANT DES DEDUCTIONS:</b>",
        { :content => "0", :align => :right },
        { :content => "----", :align => :center },
        { :content => "0", :align => :right }
    ]
    data << [ "", "", "", "" ]
    data << [
        "<b>CFA (payés):</b>", "", "",
        { :content => "#{Payslip.cfa_round(@total_pay)}", :align => :right }
    ]

    table(data,
    :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom] },
    :width => bounds.width)

    move_down 10

    vacation_summary_table
  end

end
