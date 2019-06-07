class DipesRecord < Fixy::Record
  include Fixy::Formatter::Alphanumeric
  include Fixy::Formatter::RjustAlphanumeric
  include Fixy::Formatter::Numeric

  CODE_ENREGISTREMENT = "C04"
  CNPS_REGIME = 1
  NUMERO_CONTRIBUABLE = ""
  NUMERO_EMPLOYEUR = "0105087501"
  BLANK_DIPE = "00000"
  CLE_NUMERO_EMPLOYEUR = "B"
  REGIME_CNPS = "1"
  SALAIRE_EXCEPTIONNEL = 0
  FILLER = ""

  attr_reader :row
  attr_reader :count

  set_line_ending Fixy::Record::LINE_ENDING_CRLF

  # Record Length
  set_record_length 195

  # Fields
  field :code_enregistrement,         3,    '1-3',:alphanumeric
  field :numero_dipe,                 5,    '4-8',:alphanumeric
  field :cle_numero_dipe,             1,    '9-9',:alphanumeric
  field :numero_contribuable,        14,  '10-23',:alphanumeric
  field :numero_de_feuillet ,         2,  '24-25',:numeric
  field :numero_employeur,           10,  '26-35',:numeric
  field :cle_numero_employeur,        1,  '36-36',:alphanumeric
  field :regime_cnps,                 1,  '37-37',:numeric
  field :annee_du_dipe,               4,  '38-41',:numeric
  field :numero_assure,              10,  '42-51',:alphanumeric
  field :cle_numero_assure,           1,  '52-52',:alphanumeric
  field :nombre_de_jours,             2,  '53-54',:numeric
  field :salaire_brut,               10,  '55-64',:numeric
  field :salaire_exceptionnel,       10,  '65-74',:numeric
  field :salaire_taxable,            10,  '75-84',:numeric
  field :salaire_cotisable_cnps,     10,  '85-94',:numeric
  field :salaire_cotisable_plafonne, 10, '95-104',:numeric
  field :filler,                      7,'105-111',:alphanumeric
  field :numero_de_ligne,             9,'112-120',:alphanumeric
  field :matricule_interne,          14,'121-134',:numeric
  field :emp_name,                   61,'135-195',:rjust_alpha

  def initialize(count, row)
    @row = row
    @count = count
  end


  def code_enregistrement
    CODE_ENREGISTREMENT
  end

  def numero_dipe
    BLANK_DIPE
  end

  def cle_numero_dipe
    FILLER
  end

  def numero_contribuable
    #NUMERO_CONTRIBUABLE
    FILLER
  end

  def numero_de_feuillet
    num = @row[14]
    num.to_s.rjust(2, '0')
  end

  def numero_employeur
    NUMERO_EMPLOYEUR
  end

  def cle_numero_employeur
    CLE_NUMERO_EMPLOYEUR
  end

  def regime_cnps
    REGIME_CNPS
  end

  def annee_du_dipe
    @row[2]
  end

  def numero_assure
    num = @row[3]
    (num.nil? || num.length <= 0) ? "" : num
  end

  def cle_numero_assure
    num = @row[4]
    (num.nil? || num.length <= 0) ? "" : num
  end

  def nombre_de_jours
    @row[13].to_i
  end

  def salaire_brut
    @row[5]
  end

  def salaire_exceptionnel
    SALAIRE_EXCEPTIONNEL
  end

  def salaire_taxable
    @row[6]
  end

  def salaire_cotisable_cnps
    @row[7]
  end

  def salaire_cotisable_plafonne
    @row[8]
  end

  def retenue_irpp
    @row[9]
  end

  def retenue_taxe_communale
    @row[10]
  end

  def numero_de_ligne
    num = @count
    num.to_s.rjust(9, '0')
  end

  def matricule_interne
    num = @row[12]
    num.to_s.rjust(3, '0')
  end

  def filler
    FILLER
  end

  def emp_name
    "#{@row[16]} #{@row[15]}".upcase
  end

end
