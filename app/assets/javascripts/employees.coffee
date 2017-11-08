show_hide_wage = () ->
  wage_box = $('input#employee_wage')
  if $('select#employee_echelon').val() == 'g'
    wage_box.prop('disabled', false)
    wage_box.closest('div').show('fast')
  else
    wage_box.closest('div').hide('fast')
    wage_box.prop('disabled', true)

$(document).on "turbolinks:load", ->
  window.setup_show_hide_fields($('select#employee_supervisor_id'),
                                $('div#new-sup-form'))
  window.setup_show_hide_fields($('select#employee_supervisor_person_id'),
                                $('div#name-fields'))

  show_hide_wage()
  $('select#employee_echelon').change -> show_hide_wage()
