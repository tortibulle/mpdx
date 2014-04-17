$ ->
  if $('.research_controller')[0]?
    $(document).on 'keyup', '#contact_name', ->
      name = $(this).val()
      regex = new RegExp('.*' + name + '.*', 'i')
      $('[data-hook=contact]').each ->
        if regex.test($('[data-name]', this).attr('data-name'))
          $(this).show()
        else
          $(this).hide()