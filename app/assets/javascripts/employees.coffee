$(document).on "turbolinks:load", ->
  window.setup_show_hide_fields($('select#employee_supervisor_id'),
                                $('div#new-sup-form'))
  window.setup_show_hide_fields($('select#employee_supervisor_person_id'),
                                $('div#name-fields'))

$ ->
  $("#echelon-field").change( ->
    if $("#echelon-field option:selected").text() == "g"
      $("#wage-field").prop("disabled", false)
    else
      $("#wage-field").prop("disabled", true)
  )
