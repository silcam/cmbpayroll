window.show_hide_fields = (select, to_hide) ->
  if select.val() and isNaN(select.val())  # Not an id number
    to_hide.show('fast')
  else
    to_hide.hide('fast')

window.setup_show_hide_fields = (select, to_hide) ->
  window.show_hide_fields(select, to_hide)
  select.change ->
    window.show_hide_fields(select, to_hide)

@commafy = (e) ->
  collector = []
  numAr = ('' + e).split('').reverse()
  for num,i in numAr
    do (num,i) ->
      if i % 3 == 0 and i != 0
        collector.push(",")
      collector.push(num)
  collector.reverse().join('')

$ ->
  $("input[data-commafy]").keyup ->
    $("#amount-helper").text(commafy($(this).val()))
