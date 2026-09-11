# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
# turbolinks:load, not document.ready. Turbolinks replaces the body on
# navigation without a fresh document load, so document.ready fires only if the
# page is opened directly -- and /admin/estimatepay is normally reached through
# a link_to on the admin index, which Turbolinks intercepts. The handler was
# therefore never bound on the path users actually take, and the response was
# never written into the page. Every other file here already uses
# turbolinks:load; this one was the odd one out.
$(document).on "turbolinks:load", ->
  $("#estimate-form").on("ajax:success", (event, data) ->
    $("#estimate-response").html data
  ).on "ajax:error", (event) ->
    $("#estimate-response").html "<p>ERROR</p>"
