class CnpsReport < CMBReport

  def sql

    select =<<-SELECTSTATEMENT
SELECT
  CONCAT(p.first_name, ' ', p.last_name) as name,
  e.id as id,
  e.cnps as cnps_no,
  e.dipe as dipe,
  e.title as job_description,
  CONCAT(e.category, '-', e.echelon) as cat_ech,
  e.marital_status as m_c,
  c.numchildren as children,
  p.gender
FROM
  employees e,
  people p LEFT OUTER JOIN
  (select parent_id, count(*) as numchildren from children GROUP BY parent_id) c ON
    p.id = c.parent_id
WHERE
  e.person_id = p.id
    SELECTSTATEMENT
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
