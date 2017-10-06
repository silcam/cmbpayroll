$(document).on "turbolinks:load", ->
  $('input.sick-day-checkbox').change ->
    hours_text = $(this).closest('td').find('input.hours-text').first()
    if $(this).is(':checked')
      hours_text.val('0')
      hours_text.prop('disabled', true)
    else
      hours_text.prop('disabled', false)
