$ ->
  $(document).on 'ajax:before', '.new_activity_comment', ->
    $(this).hide()

