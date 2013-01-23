$ ->
  $(document).on 'click', '#tasks_index .select_all', ->
    table = $(this).closest('table')
    $('input[type=checkbox]', table).prop('checked', $(this).prop('checked'))
    if $(this).prop('checked') == true
      $('.actions', table).show()
    else
      $('.actions', table).hide()

  $(document).on 'click', '.comment_status', ->
    $('.comments', $(this).closest('tr')).toggle()
    false

  $(document).on 'click', 'tr.task .fav', ->
    form = $(this).closest('form')
    field = $('input[name="task[starred]"]', form)
    if $(this).hasClass('ico_fav')
      field.val(false)
    else
      field.val(true)
    form.submit()
    $(this).toggleClass('ico_fav')
    $(this).toggleClass('ico_fav_off')

  # When someone marks off a task, we need to open a modal to ask the result
  $(document).on 'click', '[data-behavior=complete_task]', ->
    id = $(this).attr('data-id')
    form = $('#task_result_modal form')
    form.attr('action', '/tasks/' + id)
    $('[name=_method]', form).val('put')

    if $(this).prop('checked') == false && $('#tasks_history')[0]?
      # Uncomplete a task
      $('#task_result_task_completed').val(false)
      form.submit()
      $('#task_' + id).fadeOut()
    else
      if $(this).prop('checked') == true && !$('#tasks_completed')[0]?
        row = $('#task_' + id)
        title =  $('.taskaction', row).html()
        title += ' - ' + $('.people', row).html() if $('.people', row).html() != ''
        title += ' - ' + $('.tasktitle', row).html()

        # Marking a task off, open the result modal
        $('#task_result_modal').dialog
          title: title,
          resizable: false,
          modal:'true'
          buttons: [
            {
              text: __('Complete'),
              click: (e) ->
                $('#task_result_task_completed').val(true)
                $('form', this).submit()
                $('#task_' + id).fadeOut()
                $(this).dialog("close")
            },
            {
              text: __('Cancel'),
              click: () ->
                $(this).dialog("close")
            }
          ]

