# Turns every icon rendered by the tool_tip helper into a bootstrap
# tool-tip, which is nicer looking and quicker to appear than the browser's
# own. Bootstrap's default trigger is 'hover focus', so the icons also
# explain themselves to anyone tabbing through the form. The helper sets a
# plain title attribute too, so hovering still works if this never runs.
$(document).on "turbolinks:load", ->
  $('[data-toggle="tooltip"]').tooltip()
