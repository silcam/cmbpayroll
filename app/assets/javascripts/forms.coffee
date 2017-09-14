window.show_hide_fields = (select, to_hide) ->
  if select.val() and isNaN(select.val())  # Not an id number
    to_hide.show('fast')
  else
    to_hide.hide('fast')

window.setup_show_hide_fields = (select, to_hide) ->
  window.show_hide_fields(select, to_hide)
  select.change ->
    window.show_hide_fields(select, to_hide)