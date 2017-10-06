$(document).on "turbolinks:load", ->
  $('button#display-report').click (e) ->
    e.preventDefault()
    $('div#report-data').html("Lots of wonderful report data!")
    $('button#download-report').prop('disabled', false)