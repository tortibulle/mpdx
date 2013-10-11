$ ->
  $(document).on 'ajax:before', '.edit_donation, .new_donation', ->
    $('#js-edit_donation').dialog("destroy")
    $.mpdx.ajaxBefore()

  $(document).on 'click', '.delete_donation', ->
    $('#js-edit_donation').dialog("destroy")

