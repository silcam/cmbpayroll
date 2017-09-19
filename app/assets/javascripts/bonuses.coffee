edit_units = () ->
  if $('select#bonus_bonus_type').val() == 'percentage'
    $('span#quantity-unit').html('%')
  else
    $('span#quantity-unit').html('FCFA')

$(document).on "turbolinks:load", ->
  edit_units()
  $('select#bonus_bonus_type').change ->
    edit_units()