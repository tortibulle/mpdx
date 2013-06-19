$ ->
  $(document).on 'change', '#per_page', ->
    params = $.set_param('per_page', $(this).val())
    params = $.set_param('page', 1, params)
    document.location = document.location.pathname + '?' + params

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

  $(document).on 'ajax:before', 'a', ->
    $('#page_spinner').dialog(modal: true, closeOnEscape: false)


  $(document).ajaxComplete ->
    $('#page_spinner').dialog({ autoOpen: false }).dialog('close')

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

$.deparam = (param_string) ->
  s = param_string || document.location.search
  querystring = s.replace( /(?:^[^?#]*\?([^#]*).*$)?.*/, '$1' )
  obj = {}

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
    else obj[key] = "" if key

  obj

$.set_param = (key, value, params) ->
  params = '?' + params if params
  params = $.deparam(params)
  params[key] = value
  $.param(params)

$(document).ready ->
  element = $.deparam(location.search).focus
  $('#' + element).focus() if element
