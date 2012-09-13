$ ->

  $(document).on 'mouseleave', 'div[data-behavior=account_selector]', ->
    $('div[data-behavior=account_selector] div').hide()
    false

  $(document).on 'click', 'a[data-behavior=current_account]', ->
    $('div[data-behavior=account_selector] div').toggle()
    false

  if $('.inside.notice')[0]?
    setTimeout ->
      $('.inside.notice').fadeOut('fast')
    , 4000

  current_time = new Date()
  $.cookie('timezone', current_time.getTimezoneOffset(), { path: '/', expires: 10 } )

  # get rid of download notification when all accounts are done downloading
  if $('#data_downloading')[0]?
    data_download_interval = setInterval ->
      $.get '/home/download_data_check', (data)->
        if data == 'false'
          clearInterval(data_download_interval)
          $('#data_downloading').remove()
    , 5000

  $(document).on 'click', '.item .dismiss_item', ->
    $(this).parent().fadeOut("fast")
    false

  $(window).on 'statechange', ->
    if _gaq?
      state = History.getState()
      relativeUrl = state.url.replace(History.getRootUrl(),'')
      _gaq.push(['_trackPageview', relativeUrl])

  $.mpdx.activateTabs()

  $(document).on 'click', 'div[remote=true] a', ->
    $(this).attr('data-remote', true)
    $.rails.handleRemote($(this))
    false

  $(document).on 'click', 'a[data-behavior=remove_field]', ->
    link = this
    $(link).prev("input[type=hidden]").val("1")
    $(link).closest("[data-behavior*=field-wrapper]").hide()
    fieldset = $(link).closest('.fieldset')
    false

  $(document).on 'ajax:before', '[data-method=delete]', ->
    if $(this).attr('data-selector')?
      $(this).closest($(this).attr('data-selector')).fadeOut()
    else
      $(this).parent().fadeOut()

window.addFields = (link, association, content) ->
  new_id = new Date().getTime()
  regexp = new RegExp("new_" + association, "g")
  new_field = $(content.replace(regexp, new_id))
  $(link).closest(".sfield").before(new_field)
  fieldset = $(link).closest('[data-behavior*=add-wrapper]')
  $('.field_action', fieldset).show() # delete buttons
  $('input', new_field).focus()
  $('.country_select').selectToAutocomplete()
  false

$.mpdx = {}
$.mpdx.activateTabs = ->
  $(".tabgroup").tabs({
    select: (event, ui) ->
      window.location.hash = ui.tab.hash
  })

$.mpdx.loadDonations = ->
  if $('#donations').html() == ''
    $.ajax {
      url: '/donations',
      data: {contact_id: $('#contentbody').attr('data-contact-id')},
      dataType: 'script'
    }

$.mpdx.loadSocialStream = ->
  if $('#social').html() == ''
    $.ajax {
      url: '/social_streams',
      data: {contact_id: $('#contentbody').attr('data-contact-id')},
      dataType: 'script'
    }


