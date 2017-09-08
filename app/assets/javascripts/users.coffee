select_new_person_or_not = () ->
  new_person = $('input#new_person_true').is(':checked')
  $('select#user_person_id').prop('disabled', new_person)
  $('input#user_first_name').prop('disabled', !new_person)
  $('input#user_last_name').prop('disabled', !new_person)

$(document).on "turbolinks:load", ->
  select_new_person_or_not()

  $('input[data-new-person]').change ->
    select_new_person_or_not()