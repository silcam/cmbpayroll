update_days_summary = () ->
  $('div#days-summary').html('<br>')
  emp_id = $('select#vacation_employee_id').val()
  $.ajax(url: "/employees/"+emp_id+"/vacations/days_summary").done (html) ->
    $('div#days-summary').html(html)


$(document).on "turbolinks:load", ->
  if $('select#vacation_employee_id').size() == 1
    update_days_summary()
    $('select#vacation_employee_id').change ->
      update_days_summary()