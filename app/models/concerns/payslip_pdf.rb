class PayslipPdf < CmbPayrollPdf

  attr_reader :payslips
  attr_reader :payslip

  def initialize(payslips)
    super(:page_size => "A4", :page_layout => :landscape)
    Prawn::Font::AFM.hide_m17n_warning = true
    @payslips = payslips
  end

  def generate
    count = payslips.count

    payslips.each_with_index do |ps,index|
      payslip = Payslip.find(ps)
      @payslip = payslip

      @employee = @payslip.employee
      @start_date = @payslip.period.start
      @end_date = @payslip.period.finish
      @tax = @payslip
      @union_dues = @payslip.union_dues&.to_i
      @salary_advances = @payslip.salary_advance&.to_i
      @is_payslip = true

      @total_deductions = @payslip.first_page_deductions_sum()
      @total_pay = @payslip.total_pay()

      first_page
      second_page

      if (index + 1 < count)
        start_new_page
      end
    end
  end

  def first_page
    font_size 8

    define_grid(:columns => 4, :rows => 4, :gutter => 25)
    #grid.show_all
    #stroke_axis

    grid([0,0],[3,1]).bounding_box do

      header

      move_down 10

      data = [
        ["Taux de rémunération (mensuel)",
            { :content => "#{number_to_currency(payslip.employee.wage, locale: :cm)}", :align => :right },
            "",
            if (payslip.worked_full_month?)
              { :content => "#{payslip.employee.wage}", :align => :right }
            else
              ""
            end
        ]
      ]

      if (payslip.worked_full_month?)
        data << ["Nombre de journées", "",
            { :content => "soit CFA", :align => :center },
            { :content => "", :align => :right }]
      else
        data << ["Nombre de journées",
            { :content => "#{payslip.days} à franc #{payslip.daily_rate&.round(2)}", :align => :right },
            { :content => "soit CFA", :align => :center },
            { :content => "#{payslip.salary_earnings&.to_i}", :align => :right }]
      end

      payslip.earnings.overtime.each do |e|
        data << [
            "Heures supplémentaires",
            { :content => "#{e.hours} à franc #{e.rate.to_i}", :align => :right },
            { :content => "soit CFA", :align => :center },
            { :content => "#{e.amount.to_i == 0 ? "" : e.amount.to_i}", :align => :right }
        ]
      end

      yos = payslip.years_of_service.nil? ? 0 : payslip.years_of_service
      sb = payslip.seniority_benefit.nil? ? 0 : payslip.seniority_benefit

      data << [
          "Prime ancienneté",
          { :content => "#{number_to_percentage(yos * sb * 100, precision: 0)} de #{payslip.employee.find_base_wage}", :align => :right },
          { :content => "soit CFA", :align => :center },
          { :content => "#{payslip.seniority_bonus_amount}", :align => :right }
      ]

      pdc = payslip.prime_de_caisse
      if (pdc.nil?)
        data << [
            "Prime de caisse",
            { :content => "", :align => :right },
            { :content => "", :align => :center },
            { :content => "", :align => :right }
        ]
      else
        data << [
            "Prime de caisse",
            { :content => "#{number_to_percentage(pdc.percentage * 100, precision: 0)} de #{payslip.caissebase}", :align => :right },
            { :content => "soit CFA", :align => :center },
            { :content => "#{pdc.amount.to_i}", :align => :right }
        ]
      end

      data << [
          "<b>Autres primes</b>", "" , "", ""
      ]

      earnings = payslip.earnings.bonuses_except_pdc.each do |e|
          data << [e.description, "", "", { :content => "#{e.amount.to_i}", :align => :right }]
      end

      earnings = payslip.earnings.misc_payments.each do |e|
          data << [e.description, "", "", { :content => "#{e.amount.to_i}", :align => :right }]
      end

      table(data,
        :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
        :width => bounds.width )

      move_down 10

      table([
            ["<b>MONTANT COTISABLE</b>", { :content => "#{payslip.cnpswage}", :align => :right } ],
            ["Transport", { :content => "#{payslip.transportation}", :align => :right } ],
            ["<b>MONTANT DE LA REMUNERATION BRUT</b>", { :content =>  "#{payslip.taxable}", :align => :right } ],
            ["Contribution consensuelle", { :content => "0", :align => :right } ],
            ["", ""],
            ["<b>SALAIRE APRÈS CONTRIBUTION</b>", { :content => "#{payslip.taxable}", :align => :right } ]
      ],
      :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
      :width => bounds.width)

      move_down 10

      tax_table
    end
  end


  def second_page
    grid([0,2],[3,3]).bounding_box do

      second_page_header

      data = [
          ["<b>Salaire Net (arrondi)</b>", "", "",
          { :content => "#{Payslip.cfa_round(payslip.total_pay)}", :align => :right }]
      ]

      payslip.deductions.second_page.each do |d|
        data << [
          "#{d.note.upcase}:",
          { :content => "#{d.amount.to_i}", :align => :right },
          "", ""
        ]
      end

      data << [
          "<b>MONTANT DES DEDUCTIONS:</b>",
          { :content => "#{payslip.deductions.second_page.sum(:amount).to_i}", :align => :right },
          { :content => "----", :align => :center },
          { :content => "#{payslip.deductions.second_page.sum(:amount).to_i}", :align => :right }
      ]
      data << [ "", "", "", "" ]
      data << [
          "<b>CFA (payés):</b>", "", "",
          { :content => "#{payslip.net_pay.to_i}", :align => :right }
      ]

      table(data,
      :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom] },
      :width => bounds.width)

      move_down 10

      table([
          [
            { :content => "CONGE ACCUMULÉ", :colspan => 2 }
          ],
          ["Ce mois-ci",
            { :content => "#{payslip.vacation_earned&.round(1)} jours", :align => :right }
          ],
          ["Jusqu'aujourd'hui",
            { :content => "#{payslip.vacation_balance&.round(1)} jours", :align => :right }
          ],
          ["Derner Congé",
            { :content => "#{payslip.last_vacation_start} - #{payslip.last_vacation_end}", :align => :right }
          ],
      ],
      :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
      :position => :left )

      move_down 10
      table([
          ["#{payslip.employee.full_name}", ""],
          ["Ancien Solde du pret CFA",
              { :content => "#{Loan.total_balance(payslip.employee, payslip.period.previous).to_i}", :align => :right }],
          ["Recu pour paiement partiel du pret",
              { :content => "#{payslip.deductions.loan_payments.sum(:amount).to_i}", :align => :right }],
          ["Nouveau pret CFA",
              { :content => "#{Loan.new_loan_amount_this_period(payslip.employee, payslip.period).to_i}", :align => :right }],
          ["Solde du pret CFA",
              { :content => "#{payslip.loan_balance.to_i}", :align => :right }],
          ["", "comptable\nSIL, BP 1299, Yaoundé"],
      ],
      :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
      :position => :left )

      move_down 10

      table([
          ["DIVERS", ""],
          ["Situtation familiale", "#{I18n.t(payslip.employee.marital_status[0], scope: 'reports.marital_statuses')}"],
          ["Enfants", "#{payslip.employee.children.size}"],
          ["CNPS No", "#{payslip.employee.cnps}"],
      ],
      :cell_style => {
          :padding => 2, :inline_format => true,
          :border_width => 1, :border_color => "BBBBBB",
          :borders => [ :bottom ]
      },
      :position => :left )
    end

    grid([3,2],[3,3]).bounding_box do
      signature_box
      date_and_name
    end

  end
end
