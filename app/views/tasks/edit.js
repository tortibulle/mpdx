$('#edit_task_modal .form_wrapper').html('<%= j(render('tasks/modal_form')) %>')
$('#edit_task_modal').dialog({position:"center"})
$('[data-calendar]').datepicker({
    changeYear:true,
    dateFormat: 'yy-mm-dd',
    onSelect: function(dateText) {
        var year = dateText.substr(0,4);
        var month = dateText.substr(5,2);
        var day = dateText.substr(8,2);

      if($('[id$=start_at_1i]').length){
        $('[id$=start_at_1i]').val(year);
        $('[id$=start_at_2i]').val(month);
        $('[id$=start_at_3i]').val(day);
      }

      if($('[id$=completed_at_1i]').length){
        $('[id$=completed_at_1i]').val(year);
        $('[id$=completed_at_2i]').val(month);
        $('[id$=completed_at_3i]').val(day);
      }
    }
});
if($('#modal_task_start_at_1i').length) {
  $('[data-calendar]').datepicker('setDate', $('#modal_task_start_at_1i').val() + '-' + $('#modal_task_start_at_2i').val() + '-' + $('#modal_task_start_at_3i').val());
}

if($('#modal_task_completed_at_1i').length) {
  $('[data-calendar]').datepicker('setDate', $('#modal_task_completed_at_1i').val() + '-' + $('#modal_task_completed_at_2i').val() + '-' + $('#modal_task_completed_at_3i').val());
}