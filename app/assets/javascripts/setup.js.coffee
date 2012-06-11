$ ->
  $(document).on 'click', '#connect_to_org', ->
    return false if $('#organization_id').val() == ''
    el = $('#org_connection_box')
    el.dialog
      resizable: false,
      height:'auto',
      width:400,
      modal: true

    $.ajax {
      url: $(this).attr('href'),
      data: {id: $('#organization_id').val()},
      dataType: 'script'
    }
    false


