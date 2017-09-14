show_hide_name_fields = () ->
  if isNaN($('select#supervisor_person_id').val())  # Create New as opposed to the id of a Person
    $('div#name-fields').show('fast')
  else
    $('div#name-fields').hide('fast')

$(document).on "turbolinks:load", ->
  show_hide_name_fields()
  $('select#supervisor_person_id').change ->
    show_hide_name_fields()