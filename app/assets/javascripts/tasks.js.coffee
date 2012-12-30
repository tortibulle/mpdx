$ ->
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
    if $(this).prop('checked') == false && $('#tasks_history')[0]?
      # Uncomplete a task
      form = $('#task_' + id + '_edit_task_' + id)
      form.submit()
      $('#task_' + id).fadeOut()
    else
      if $(this).prop('checked') == true && !$('#tasks_completed')[0]?
        # Marking a task off, open the result modal
        $('#result_modal_' + id).dialog
          resizable: false,
          modal:'true'
          buttons: [
            {
              text: __('Complete'),
              click: (e) ->
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

