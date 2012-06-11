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

  $(document).on 'click', '[data-behavior=complete_task]', ->
    id = $(this).attr('data-id')
    form = $('#task_' + id + '_edit_task_' + id)
    $('input[name="task[completed]"]', form).val($(this).prop('checked'))
    form.submit()
    if ($(this).prop('checked') == true && !$('#tasks_completed')[0]? ||
        $(this).prop('checked') == false && $('#tasks_completed')[0]?)
      $('#task_' + id).fadeOut()
