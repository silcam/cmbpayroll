$(document).on "turbolinks:load", ->
  window.setup_show_hide_fields($('select#standard_charge_note_id'),
                                $('input#charge_note'))