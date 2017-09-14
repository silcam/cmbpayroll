$(document).on "turbolinks:load", ->
  window.setup_show_hide_fields($('select#supervisor_person_id'),
    $('div#name-fields'))
