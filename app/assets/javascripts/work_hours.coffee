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
    if $(this).hasClass('off-day-field')
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

  $(".toggle-dept").each ->
    if $(this).is(':checked')
      $(this).siblings(".toggle-on-checkbox").show()
      $(this).siblings(".toggle-on-checkbox").prop("disabled", false)

$ ->
  $(".toggle-dept").on("click", () ->
    if $(this).is(':checked')
      $(this).siblings(".toggle-on-checkbox").show()
      $(this).siblings(".toggle-on-checkbox").prop("disabled", false)
    else
      $(this).siblings(".toggle-on-checkbox").hide()
      $(this).siblings(".toggle-on-checkbox").prop("disabled", true)
  )
