$(document).on "turbolinks:load", ->
  window.setup_show_hide_fields($('select#employee_supervisor_id'),
                                $('div#new-sup-form'))
  window.setup_show_hide_fields($('select#employee_supervisor_person_id'),
                                $('div#name-fields'))