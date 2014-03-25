$ ->
  if $('.google_integrations_controller')[0]?
    $(document).on 'click', '#new_calendar_link', ->
      $(this).hide()
      $('#new_calendar_form').show()