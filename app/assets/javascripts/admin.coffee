# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
$(document).ready ->
  $("#estimate-form").on("ajax:success", (event, data) ->
    $("#estimate-response").html data
  ).on "ajax:error", (event) ->
    $("#estimate-response").html "<p>ERROR</p>"
