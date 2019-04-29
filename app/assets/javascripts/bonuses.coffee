edit_units = () ->
  btype = $('select#bonus_bonus_type').val()
  if btype == 'percentage' || btype == 'base_percentage'
    $('span#quantity-unit').html('%')
  else
    $('span#quantity-unit').html('FCFA')

$(document).on "turbolinks:load", ->
  edit_units()
  $('select#bonus_bonus_type').change ->
    edit_units()
