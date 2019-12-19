$(document).on "turbolinks:load", ->
  $('input.excused-absence-checkbox').change ->
    excuse_section = $(this).closest('td').find('div.excuse-section').first()
    if $(this).is(':checked')
      excuse_section.find('input.excused-hours-excuse').prop('disabled', false)
      excuse_section.slideDown('fast')
    else
      excuse_section.slideUp('fast')
      excuse_section.find('input.excused-hours-excuse').prop('disabled', true)
      excuse_section.find('input.excused-hours').val(0)

$ ->
  $('body').on 'click', '#fill-all-btn', ->
    $('#fill-all-btn').html('Working...')
    true
