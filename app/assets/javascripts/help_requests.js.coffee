$ ->
  $(document).on 'change', '#help_request_request_type', ->
    if $(this).val() == ''
      $('#request_fields').hide()
    else
      $('#request_fields').show()

