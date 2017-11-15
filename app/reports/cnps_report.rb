class CnpsReport < CMBReport

  def sql

    select =<<-SELECTSTATEMENT
CONCAT(people.first_name, ' ', people.last_name) as name,
employees.id as id,
employees.cnps as cnps_no,
employees.dipe as dipe,
employees.title as job_description,
CONCAT(employees.category, '-', employees.echelon) as cat_ech,
employees.marital_status as m_c,
employees.id as children,
people.gender
    SELECTSTATEMENT

    Employee.select(select).joins(:person).all().to_sql
  end

  def formatted_title
    I18n::t(:Cnps_report, scope: [:reports])
  end

  def format_header(column_name)
    custom_headers = {
      children: 'Child',
      m_c: 'Mar',
      cat_ech: 'Cat/Ech'
    }
    custom_headers.fetch(column_name.to_sym) { super }
  end

end
