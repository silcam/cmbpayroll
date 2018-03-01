prawn_document(page_layout: :landscape) do |pdf|

  pdf.font_size 8

  pdf.define_grid(:columns => 4, :rows => 4, :gutter => 25)
  #pdf.grid.show_all
  #pdf.stroke_axis

  pdf.grid([0,0],[3,1]).bounding_box do

    pdf.text "Bulletin de Paie", :font_size => 14

    pdf.horizontal_line 0, pdf.bounds.width
    pdf.move_down 3
    pdf.horizontal_line 0, pdf.bounds.width

    pdf.move_down 10

    pdf.table([
        ["Raison sociale", "SIL",
            { :content => "No. d'immatriculation: #{SystemVariable.value(:immatriculation_no)}", :align => :right }
        ],
        ["", "BP 1299, Yaoundé",
            { :content => "Paie du #{@payslip.period.start} à #{@payslip.period.finish}", :align => :right }
        ]
    ],
    :cell_style => { :padding => 2, :borders => [] },
    :width => pdf.bounds.width )

    pdf.move_down 10

    pdf.table([
        ["Nom du travailleur", "#{@payslip.employee.full_name}", "Matricule No.", "#{@payslip.employee.id}" ],
        ["Catégoire professionnelle",
            { :content => "#{@payslip.employee.title}", :colspan => 2 },
         "#{@payslip.employee.category_roman}-#{@payslip.employee.echelon.upcase}" ],
    ],
    :cell_style => { :padding => 2, :borders => [] },
    :width => pdf.bounds.width )

    pdf.move_down 10

    data = [
      ["Taux de rémunération (mensuel)",
          { :content => "#{number_to_currency(@payslip.employee.wage, locale: :cm)}", :align => :right },
          "",
          { :content => "#{@payslip.employee.wage}", :align => :right }
      ]
    ]

    if (@payslip.worked_full_month?)
      data << ["Nombre de journées", "",
          { :content => "soit CFA", :align => :center },
          { :content => "", :align => :right }]
    else
      data << ["Nombre de journées",
          { :content => "moins #{@payslip.employee.workdays_per_month(@payslip.period) - (@payslip.days.nil? ? 0 : @payslip.days)} à franc #{@payslip.daily_rate.round(2)}", :align => :right },
          { :content => "soit CFA", :align => :center },
          { :content => "#{@payslip.salary_earnings&.to_i}", :align => :right }]
    end

    @payslip.earnings.overtime.each do |e|
      data << [
          "Heures supplémentaires",
          { :content => "#{e.hours} à franc #{e.rate.to_i}", :align => :right },
          { :content => "soit CFA", :align => :center },
          { :content => "#{e.amount.to_i == 0 ? "" : e.amount.to_i}", :align => :right }
      ]
    end

    yos = @payslip.years_of_service.nil? ? 0 : @payslip.years_of_service
    sb = @payslip.seniority_benefit.nil? ? 0 : @payslip.seniority_benefit

    data << [
        "Prime ancienneté",
        { :content => "#{number_to_percentage(yos * sb * 100, precision: 0)} de #{@payslip.employee.find_base_wage}", :align => :right },
        { :content => "soit CFA", :align => :center },
        { :content => "#{@payslip.seniority_bonus_amount}", :align => :right }
    ]

    pdc = @payslip.prime_de_caisse
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
          { :content => "#{number_to_percentage(pdc.percentage * 100, precision: 0)} de #{@payslip.caissebase}", :align => :right },
          { :content => "soit CFA", :align => :center },
          { :content => "#{pdc.amount.to_i}", :align => :right }
      ]
    end

    data << [
      "<b>Autres primes</b>", "" , "", ""
    ]

    earnings = @payslip.earnings.bonuses_except_pdc.each do |e|
      data << [e.description, "", "", { :content => "#{e.amount.to_i}", :align => :right }]
    end

    earnings = @payslip.earnings.misc_payments.each do |e|
      data << [e.description, "", "", { :content => "#{e.amount.to_i}", :align => :right }]
    end

    pdf.table(data,
    :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
    :width => pdf.bounds.width )

    pdf.move_down 10

    pdf.table([
        ["<b>MONTANT COTISABLE</b>", { :content => "#{@payslip.cnpswage}", :align => :right } ],
        ["Transport", { :content => "#{@payslip.transportation}", :align => :right } ],
        ["<b>MONTANT DE LA REMUNERATION BRUT</b>", { :content =>  "#{@payslip.taxable}", :align => :right } ],
        ["Contribution consensuelle", { :content => "0", :align => :right } ],
        ["", ""],
        ["<b>SALAIRE APRÈS CONTRIBUTION</b>", { :content => "#{@payslip.taxable}", :align => :right } ]
    ],
    :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
    :width => pdf.bounds.width)

    pdf.move_down 10

    pdf.table([
        ["<b>Déductions</b>", "", "", "", ""],
        ["IRPP:", "",
            { :content => "#{@payslip.proportional}", :align => :right }, "", "" ],
        ["C.A.C.:", "",
            { :content => "#{@payslip.cac}", :align => :right }, "", ""],
        ["Taxe communale:","",
            { :content => "#{@payslip.communal}", :align => :right }, "", "" ],
        ["Pension vieillesse 4,2%:", "",
            { :content => "#{@payslip.cnps}", :align => :right }, "", "" ],
        ["Cotisation syndicale:", "",
            { :content => "#{@payslip.union_dues.to_i}", :align => :right }, "", "" ],
        ["Crédit foncier:", "",
            { :content => "#{@payslip.ccf}", :align => :right }, "", "" ],
        ["Audio-visuelle:", "",
            { :content => "#{@payslip.crtv}", :align => :right }, "", "" ],
        ["Acomptes sur salaire:", "",
            { :content => "#{@payslip.salary_advance.to_i}", :align => :right }, "", "" ],
        ["<b>MONTANT DES DEDUCTIONS</b>", "",
            { :content => "#{@payslip.first_page_deductions_sum()}", :align => :right },
            { :content => "-----", :align => :center },
            { :content => "#{@payslip.first_page_deductions_sum()}", :align => :right } ],
        ["", "", "", "", "" ],
        ["<b>MONTANT DE LA PAIE</b>", "", "", "", { :content => "#{@payslip.taxable - ( @payslip.total_tax + @payslip.union_dues.to_i + @payslip.salary_advance.to_i ) }", :align => :right } ]
    ],
    :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
    :width => pdf.bounds.width)
  end

  pdf.grid([0,2],[3,3]).bounding_box do

    pdf.text "Deductions Du Salaire", :align => :center
    pdf.text "31/01/2018", :align => :center

    pdf.move_down 10

    pdf.text "Nom: #{@payslip.employee.full_name}"

    pdf.move_down 10

    data = [
        ["<b>Salaire Net (arrondi)</b>", "", "",
        { :content => "#{Payslip.cfa_round(@payslip.taxable - ( @payslip.total_tax + @payslip.union_dues.to_i + @payslip.salary_advance.to_i ))}", :align => :right }]
    ]

    @payslip.deductions.second_page.each do |d|
      data << [
        "#{d.note.upcase}:",
        { :content => "#{d.amount.to_i}", :align => :right },
        "", ""
      ]
    end

    data << [
        "<b>MONTANT DES DEDUCTIONS:</b>",
        { :content => "#{@payslip.deductions.second_page.sum(:amount).to_i}", :align => :right },
        { :content => "----", :align => :center },
        { :content => "#{@payslip.deductions.second_page.sum(:amount).to_i}", :align => :right }
    ]
    data << [ "", "", "", "" ]
    data << [
        "<b>CFA (payés):</b>", "", "",
        { :content => "#{@payslip.net_pay.to_i}", :align => :right }
    ]

    pdf.table(data,
    :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom] },
    :width => pdf.bounds.width)

    pdf.move_down 10

    pdf.table([
        [
          { :content => "CONGE ACCUMULÉ", :colspan => 2 }
        ],
        ["Ce mois-ci",
          { :content => "#{@payslip.vacation_earned} jours", :align => :right }
        ],
        ["Jusqu'aujourd'hui",
          { :content => "#{@payslip.vacation_balance} jours", :align => :right }
        ],
        ["Derner Congé",
          { :content => "#{@payslip.last_vacation_start} - #{@payslip.last_vacation_end}", :align => :right }
        ],
    ],
    :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
    :position => :left )

    pdf.move_down 10

    pdf.table([
        ["#{@payslip.employee.full_name}", ""],
        ["Ancien Solde du pret CFA",
            { :content => "#{Loan.total_balance(@payslip.employee, @payslip.period.previous).to_i}", :align => :right }],
        ["Recu pour paiement partiel du pret",
            { :content => "#{@payslip.deductions.loan_payments.sum(:amount).to_i}", :align => :right }],
        ["Nouveau pret CFA",
            { :content => "#{Loan.new_loan_amount_this_period(@payslip.employee, @payslip.period).to_i}", :align => :right }],
        ["Solde du pret CFA",
            { :content => "#{@payslip.loan_balance.to_i}", :align => :right }],
        ["", "comptable\nSIL, BP 1299, Yaoundé"],
    ],
    :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
    :position => :left )

    pdf.move_down 10

    pdf.table([
        ["DIVERS", ""],
        ["Situtation familiale", "#{I18n.t(@payslip.employee.marital_status[0], scope: 'reports.marital_statuses')}"],
        ["Enfants", "#{@payslip.employee.children.size}"],
        ["CNPS No", "#{@payslip.employee.cnps}"],
    ],
    :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
    :position => :left )

  end

  pdf.grid([3,2],[3,3]).bounding_box do

    pdf.text "Signature de l'employé:\n#{@payslip.period.finish}", :valign => :middle
    pdf.text "#{@payslip.employee.full_name} -- #{@payslip.period.finish}", :valign => :bottom, :align => :right

  end

end
