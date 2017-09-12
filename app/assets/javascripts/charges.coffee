show_hide_charge_note = () ->
  if isNaN($('select#standard_charge_note_id').val())  # Other/Autre as opposed to the id of a StandardChargeNote
    $('input#charge_note').show('fast')
  else
    $('input#charge_note').hide('fast')

$(document).on "turbolinks:load", ->
  show_hide_charge_note()
  $('select#standard_charge_note_id').change ->
    show_hide_charge_note()