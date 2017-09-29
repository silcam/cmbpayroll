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

  # This is dumb.  Rails enums are dumb.
  def fixup_enum(value, options, t_symbol = nil)

    scope = [ :reports]
    scope << t_symbol if t_symbol

    output = options.key(value)
    I18n.t(output.gsub(/^([a-z]{1}).*$/, '\1'), scope: scope, default: output) if output
  end

end
