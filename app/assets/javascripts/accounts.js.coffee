$ ->
  if $('#accounts_index')?

    $(document).on 'click', '[data-behavior="show_import"]', ->
      $(this).closest('div').hide()
      div = $(this).closest('[data-behavior="account"]')
      $('[data-behavior="import_options"]', div).show()
      false

    $(document).on 'click', '[data-behavior="import_button"]', ->
      $(this).closest('form').submit()
      false

    $(document).on 'click', '[data-behavior="add_org_account"]', ->
      $('[data-behavior="new_org_account"]').dialog
        resizable: false,
        modal:'true'
      false
    $(document).on 'click', '#connect_to_org', ->
      $('[data-behavior="new_org_account"]').dialog('destroy')
      false
