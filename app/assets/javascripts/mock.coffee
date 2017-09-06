# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

update_elements = (regular, overtime) ->
  $('input#hours_regular').val(regular)
  $('input#hours_overtime').val(overtime)
  save = $('div#translated_save').text()
  $('input#hours-submit').val(save)

recalculate_hours = () ->
  regular = 0
  overtime = 0
  $('input[data-dow]').each ->
    hours = parseFloat($(this).val())
    wday = $(this).data('dow')
    if wday < 1 or wday > 5  # 0 == Sunday, 6 == Saturday
      overtime += hours
    else if hours > 8
      regular += 8
      overtime += hours - 8
    else
      regular += hours
  update_elements(regular, overtime)

$(document).on "turbolinks:load", ->
  if $('input[data-dow]').length > 0
    recalculate_hours()

  $('input[data-dow]').change ->
    recalculate_hours()

  $('button#display-report').click (e) ->
    e.preventDefault()
    $('div#report-data').html("Lots of wonderful report data!")
    $('button#download-report').prop('disabled', false)
