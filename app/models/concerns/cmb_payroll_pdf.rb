class CmbPayrollPdf < Prawn::Document
  extend ActiveSupport::Concern

  attr_reader :employee
  attr_reader :start_date
  attr_reader :end_date
  attr_reader :tax

  def header
      image "#{Rails.root}/app/assets/images/2014_sil_logo.png",
        :width => 42, :height => 50

      bounding_box([45, cursor + 50], :width => 320, :height => 50) do

        if (@is_payslip)
          font_size(14) do
            text "Bulletin de Paie"
          end
        else
          font_size(14) do
            text "Bulletin de Paie - CONGE"
          end
        end

        table(
        [
            [
              "Raison sociale",
              "SIL",
              { :content => "No. d'immatriculation: #{SystemVariable.value(:immatriculation_no)}", :align => :right }
            ],
            [
              "",
              "BP 1299, Yaoundé",
              { :content => "Paie du #{@start_date} à #{@end_date}", :align => :right }
            ]
        ],
        :cell_style => { :padding => 2, :borders => [] },
        :width => bounds.width )

      end

      #move_down 10


      #move_down 10

      table([
          ["Nom du travailleur", "#{@employee.full_name_rev}", "Matricule No.", "#{@employee.id}" ],
          ["Catégoire professionnelle",
              { :content => "#{@employee.title}", :colspan => 2 },
           "#{display_category_roman(@category)}-#{display_echelon(@echelon)}" ],
      ],
      :cell_style => { :padding => 2, :borders => [] },
      :width => bounds.width )
  end

  def signature_box
    text "Signature de l'employé:\n#{Date.today}", :valign => :middle
  end

  def date_and_name
      text "#{@employee.full_name_rev} -- #{Date.today}", :valign => :bottom, :align => :right
  end

  def tax_table
    table([
          ["<b>Déductions</b>", "", "", "", ""],
          ["IRPP:", "",
              { :content => "#{@tax.proportional}", :align => :right }, "", "" ],
          ["C.A.C.:", "",
              { :content => "#{@tax.cac}", :align => :right }, "", ""],
          ["Taxe communale:","",
              { :content => "#{@tax.communal}", :align => :right }, "", "" ],
          ["Pension vieillesse 4,2%:", "",
              { :content => "#{@tax.cnps}", :align => :right }, "", "" ],
          ["Cotisation syndicale:", "",
              { :content => "#{@union_dues}", :align => :right }, "", "" ],
          ["Crédit foncier:", "",
              { :content => "#{@tax.ccf}", :align => :right }, "", "" ],
          ["Audio-visuelle:", "",
              { :content => "#{@tax.crtv}", :align => :right }, "", "" ],
          ["<b>MONTANT DES DEDUCTIONS</b>", "",
              { :content => "#{@total_deductions}", :align => :right },
              { :content => "-----", :align => :center },
              { :content => "#{@total_deductions}", :align => :right } ],
          ["", "", "", "", "" ],
          ["<b>MONTANT DE LA PAIE</b>", "", "", "", { :content => "#{@total_pay}", :align => :right } ]
      ],
      :cell_style => { :padding => 2, :inline_format => true, :border_width => 1, :border_color => "BBBBBB", :borders => [ :bottom ] },
      :width => bounds.width)
  end

  def second_page_header
    font_size(12) do
      text "Deductions Du Salaire", :align => :center
    end
    text "#{@end_date}", :align => :center

    move_down 10

    text "Nom: #{@employee.full_name_rev}"

    move_down 10
  end

end

