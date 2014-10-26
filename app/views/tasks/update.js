<% @task = nil %>
$('#edit_task_modal').dialog('close')
$('#edit_task_modal .form_wrapper').html('<%= j(render('tasks/modal_form')) %>')
$.mpdx.reloadContactTasksAndHistory()
