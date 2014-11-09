$ = window.jQuery
$.paste = (pasteContainer) ->
  console?.log "DEPRECATED: This method is deprecated. Please use $.fn.pastableNonInputable() instead."
  pm = Paste.mountNonInputable pasteContainer
  pm._container
$.fn.pastableNonInputable = ->
  for el in @
    paste = Paste.mountNonInputable el
  @
$.fn.pastableTextarea = ->
  for el in @
    paste = Paste.mountTextarea el
  @
$.fn.pastableContenteditable = ->
  for el in @
    paste = Paste.mountContenteditable el
  @

createHiddenEditable = ->
  $(document.createElement 'div')
  .attr 'contenteditable', true
  .css
    width: 1
    height: 1
    position: 'fixed'
    left: -100
    overflow: 'hidden'

class Paste
  # Element to receive final events.
  _target: null

  # Actual element to do pasting.
  _container: null

  @mountNonInputable: (nonInputable)->
    paste = new Paste createHiddenEditable().appendTo(nonInputable), nonInputable
    $(nonInputable).on 'click', => paste._container.focus()

    paste._container.on 'focus', => $(nonInputable).addClass 'pastable-focus'
    paste._container.on 'blur', => $(nonInputable).removeClass 'pastable-focus'


  @mountTextarea: (textarea)->
    return @mountContenteditable textarea unless window.ClipboardEvent
    # Firefox only
    paste = new Paste createHiddenEditable().insertBefore(textarea), textarea
    $(textarea).on 'keypress', (ev)=>
      return unless 'v' == String.fromCharCode ev.charCode
      return unless ev.ctrlKey || ev.metaKey
      paste._container.focus()
    $(paste._target).on 'pasteImage', =>
      $(textarea).focus()
    $(paste._target).on 'pasteText', =>
      $(textarea).focus()
    
    $(textarea).on 'focus', => $(textarea).addClass 'pastable-focus'
    $(textarea).on 'blur', => $(textarea).removeClass 'pastable-focus'

  @mountContenteditable: (contenteditable)->
    paste = new Paste contenteditable, contenteditable
    
    $(contenteditable).on 'focus', => $(contenteditable).addClass 'pastable-focus'
    $(contenteditable).on 'blur', => $(contenteditable).removeClass 'pastable-focus'


  constructor: (@_container, @_target)->
    @_container = $ @_container
    @_target = $ @_target
    .addClass 'pastable'
    @_container.on 'paste', (ev)=>
      if ev.originalEvent?.clipboardData?
        clipboardData = ev.originalEvent.clipboardData
        if clipboardData.items 
          # Chrome & Safari(text-only)
          for item in clipboardData.items
            if item.type.match /^image\//
              reader = new FileReader()
              reader.onload = (event)=>
                @_handleImage event.target.result
              reader.readAsDataURL item.getAsFile()
            if item.type == 'text/plain'
              item.getAsString (string)=>
                @_target.trigger 'pasteText', text: string
        else
          # Firefox
          if clipboardData.types.length
            text = clipboardData.getData 'Text'
            @_target.trigger 'pasteText', text: text
          else
            @_checkImagesInContainer (src)=>
              @_handleImage src
      # IE
      if clipboardData = window.clipboardData 
        if (text = clipboardData.getData 'Text')?.length
          @_target.trigger 'pasteText', text: text
        else
          for file in clipboardData.files
            @_handleImage URL.createObjectURL(file)
            @_checkImagesInContainer ->

  _handleImage: (src)->
    loader = new Image()
    loader.onload = =>
      canvas = document.createElement 'canvas'
      canvas.width = loader.width
      canvas.height = loader.height
      ctx = canvas.getContext '2d'
      ctx.drawImage loader, 0, 0, canvas.width, canvas.height
      dataURL = null
      try 
        dataURL = canvas.toDataURL 'image/png'
      if dataURL
        @_target.trigger 'pasteImage',
          dataURL: dataURL
          width: loader.width
          height: loader.height
    loader.src = src

  _checkImagesInContainer: (cb)->
    timespan = Math.floor 1000 * Math.random()
    img["_paste_marked_#{timespan}"] = true for img in @_container.find('img')
    setTimeout =>
      for img in @_container.find('img')
        cb img.src unless img["_paste_marked_#{timespan}"]
        $(img).remove()
    , 1
