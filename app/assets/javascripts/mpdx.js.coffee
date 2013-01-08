$ ->

  #$('select[multiple=multiple]').MultiSelect()

  $(document).on 'click', '#leftmenu ul.left_filters li label', ->
    $(this).next(".collapse").slideToggle('fast')
    $(this).toggleClass("opened")
    $(this).parent("li").toggleClass("opened")

  $('.tip, .qtip').tooltipsy()

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

# Stub method for translation
window.__ = (val) ->
  val

# Replace built in rails confirmation method
$.rails.allowAction = (element) ->
  message = element.data('confirm')
  if message
    div = $('#confirmation_modal')
    div.html(message)
    div.dialog {
      buttons: [
        {
          text: __('Yes'),
          click: ->
            $.rails.confirmed(element)
            $(this).dialog("close")
        },
        {
          text: __('No'),
          click: ->
            $(this).dialog("close")
        },
      ]
    }
    false
  else
    true

$.rails.confirmed = (element) ->
  element.removeAttr('data-confirm')
  element.removeData('confirm')
  element.trigger('click.rails')

$.deparam = (coerce) ->
  s = document.location.search
  querystring = s.replace( /(?:^[^?#]*\?([^#]*).*$)?.*/, '$1' )
  obj = {}
  coerce_types =
    true: not 0
    false: not 1
    null: null

  $.each querystring.replace(/\+/g, " ").split("&"), (j, v) ->
    param = v.split("=")
    key = decodeURIComponent(param[0])
    val = undefined
    cur = obj
    i = 0
    keys = key.split("][")
    keys_last = keys.length - 1
    if /\[/.test(keys[0]) and /\]$/.test(keys[keys_last])
      keys[keys_last] = keys[keys_last].replace(/\]$/, "")
      keys = keys.shift().split("[").concat(keys)
      keys_last = keys.length - 1
    else
      keys_last = 0
    if param.length is 2
      val = decodeURIComponent(param[1])
      val = (if val and not isNaN(val) then +val else (if val is "undefined" then `undefined` else (if coerce_types[val] isnt `undefined` then coerce_types[val] else val)))  if coerce
      if keys_last
        while i <= keys_last
          key = (if keys[i] is "" then cur.length else keys[i])
          cur = cur[key] = (if i < keys_last then cur[key] or (if keys[i + 1] and isNaN(keys[i + 1]) then {} else []) else val)
          i++
      else
        if $.isArray(obj[key])
          obj[key].push val
        else if obj[key] isnt `undefined`
          obj[key] = [ obj[key], val ]
        else
          obj[key] = val
    else obj[key] = (if coerce then `undefined` else "")  if key

  obj

$.set_param = (key, value) ->
  params = $.deparam()
  params[key] = value
  console.log(params)
  $.param(params)
