class CMBReport < Dossier::Report

  def set_options(options={})
    @options = options
  end

  def report_period
    begin
      return Period.fr_str(@options[:period])
    rescue Period::InvalidPeriod
      # ignore, let this fall through to use current period
    end
    Period.current
  end

  def period
    options[:period]
  end

  def format_cat_ech(value)
    cat, ech = value.split('-')

    newcat = Employee.categories.invert[cat.to_i]
    newech = Employee.echelons.invert[ech.to_i]

    "#{word_to_int(newcat)}-#{newech}"
  end

  # This is dumb.  Rails enums are dumb.
  def fixup_enum(value, options, t_symbol = nil)

    scope = [ :reports]
    scope << t_symbol if t_symbol

    output = options.key(value)
    I18n.t(output.gsub(/^([a-z]{1}).*$/, '\1'), scope: scope, default: output) if output
  end

  # Options selector
  def year
    period = options[:period]
    year, month = period.split('-')
    if (year.nil?)
      Period.current.year
    else
      year
    end
  end

  # Options selector
  def month
    period = options[:period]
    year, month = period.split('-')
    if (month.nil?)
      Period.current.month
    else
      month
    end
  end

  def format_children(value)
    if value.nil?
      0
    else
      value
    end
  end

  def format_gender(value)
    fixup_enum(value, Person.genders, :genders)
  end

  def format_m_c(value)
    fixup_enum(value, Employee.marital_statuses, :marital_statuses)
  end

  def format_base_wage(value)
    cfa(value)
  end

  def format_per(value)
    fixup_enum(value, Employee.employment_statuses, :employment_statuses)
  end

  def cfa(value)
    formatter.number_to_currency(value, locale: :cm)
  end

end
