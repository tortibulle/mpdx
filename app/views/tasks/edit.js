$('#edit_task_modal .form_wrapper').html('<%= j(render('tasks/modal_form')) %>')
$('#edit_task_modal').dialog({position:"center"})
