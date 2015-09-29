SpanBranch = require './span-branch'
SpanLeaf = require './span-leaf'
{Emitter} = require 'atom'
assert = require 'assert'
Span = require './span'

class SpanBuffer extends SpanBranch

  constructor: (children) ->
    children ?= [new SpanLeaf([])]
    super(children)
    @isRoot = true
    @emitter = null
    @changing = 0

  clone: ->
    super()

  destroy: ->
    unless @destroyed
      @destroyed = true
      @emitter?.emit 'did-destroy'

  ###
  Section: Events
  ###

  _getEmitter: ->
    unless emitter = @emitter
      @emitter = emitter = new Emitter
    emitter

  onWillChange: (callback) ->
    @_getEmitter().on 'will-change', callback

  onDidChange: (callback) ->
    @_getEmitter().on 'did-change', callback

  onDidDestroy: (callback) ->
    @_getEmitter().on 'did-destroy', callback

  ###
  Section: Characters
  ###

  deleteRange: (location, length) ->
    unless length
      return
    @replaceRange(location, length, '')

  insertString: (location, string) ->
    unless string
      return
    @replaceRange(location, 0, string)

  replaceRange: (location, length, string) ->
    if location < 0 or (location + length) > @getLength()
      throw new Error("Invalide text range: #{location}-#{location + length}")

    if @emitter and not @changing
      changeEvent =
        location: location
        replacedLength: length
        insertedString: string
      @emitter.emit 'will-change', changeEvent

    @changing++
    if @getSpanCount() is 0
      @insertSpans(0, [@createSpan(string)])
    else
      start = @getSpanInfoAtLocation(location)
      spanLength = start.span.getLength()

      if start.location + length <= spanLength and length isnt spanLength
        start.span.replaceRange(start.location, length, string)
      else
        slice = @sliceSpansToRange(location, length)
        if start.location is 0 and string.length
          start.span.replaceRange(0, start.span.getLength(), string)
          @removeSpans(slice.spanIndex + 1, slice.count - 1)
        else
          @removeSpans(slice.spanIndex, slice.count)
          if string
            start = @getSpanInfoAtLocation(location)
            start.span.appendString(string)
    @changing--

    if changeEvent
      @emitter.emit 'did-change', changeEvent

  ###
  Section: Spans
  ###

  createSpan: (text) ->
    new Span(text)

  insertSpans: (spanIndex, spans, adjustChangeEvent) ->
    if spanIndex < 0 or spanIndex > @getSpanCount()
      throw new Error("Invalide span index: #{spanIndex}")

    unless spans.length
      return

    if @emitter and not @changing
      insertedString = (each.getString() for each in spans).join('')
      changeEvent =
        location: @getSpan(spanIndex)?.getLocation() ? @getLength()
        replacedLength: 0
        insertedString: insertedString
      adjustChangeEvent?(changeEvent)
      @emitter.emit 'will-change', changeEvent

    @changing++
    super(spanIndex, spans)
    @changing--

    if changeEvent
      @emitter.emit 'did-change', changeEvent

  removeSpans: (spanIndex, removeCount, adjustChangeEvent) ->
    if spanIndex < 0 or (spanIndex + removeCount) > @getSpanCount()
      throw new Error("Invalide span range: #{spanIndex}-#{spanIndex + removeCount}")

    unless removeCount
      return

    if @emitter and not @changing
      replacedLength = 0
      @iterateSpans spanIndex, removeCount, (span) ->
        replacedLength += span.getLength()
      changeEvent =
        location: @getSpan(spanIndex).getLocation()
        replacedLength: replacedLength
        insertedString: ''
      adjustChangeEvent?(changeEvent)
      @emitter.emit 'will-change', changeEvent

    @changing++
    super(spanIndex, removeCount)
    @changing--

    if changeEvent
      @emitter.emit 'did-change', changeEvent

  getSpansInRange: (location, length, chooseRight=false) ->
    range = @getSpanRangeForCharacterRange(location, length, chooseRight)
    @getSpans(range.location, range.length)

  getSpanRangeForCharacterRange: (location, length, chooseRight=false) ->
    start = @getSpanInfoAtLocation(location, chooseRight)
    end = @getSpanInfoAtLocation(location + length, chooseRight)
    if end.location is 0 and end.spanIndex isnt start.spanIndex
      end.spanIndex--
    {} =
      location: start.spanIndex
      length: (end.spanIndex - start.spanIndex) + 1

  getSpanInfoAtCharacterIndex: (characterIndex) ->
    if characterIndex < @getLength()
      @getSpanInfoAtLocation(characterIndex, true)
    else
      throw new Error("Invalide character index: #{characterIndex}")

  getSpanInfoAtLocation: (location, chooseRight=false) ->
    if location > @getLength()
      throw new Error("Invalide cursor location: #{location}")
    if chooseRight
      if location is @getLength()
        lastSpanBuffer = @getSpanCount() - 1
        lastSpan = @getSpan(lastSpanBuffer)
        spanInfo =
          span: lastSpan
          spanIndex: lastSpanBuffer
          location: lastSpan.getLength()
          spanLocation: location - lastSpan.getLength()
      else
        spanInfo = super(location + 1)
        spanInfo.location--
    else
      spanInfo = super(location)
    spanInfo

  sliceSpanAtLocation: (location) ->
    start = @getSpanInfoAtLocation(location)
    if startSplit = start.span.split(start.location)
      @insertSpans(start.spanIndex + 1, [startSplit])
    start

  sliceSpansToRange: (location, length) ->
    assert(length > 0)
    start = @sliceSpanAtLocation(location)
    if start.location is start.span.getLength()
      start.spanIndex++
    end = @sliceSpanAtLocation(location + length)
    {} =
      spanIndex: start.spanIndex
      count: (end.spanIndex - start.spanIndex) + 1

  replaceSpansFromLocation: (location, spans) ->
    totalLength = 0
    for each in spans
      totalLength += each.getLength()
    slice = @sliceSpansToRange(location, totalLength)
    @removeSpans(slice.spanIndex, slice.count)
    @insertSpans(slice.spanIndex, spans)

  ###
  Section: Debug
  ###

  toString: ->
    spanStrings = []
    @iterateSpans 0, @getSpanCount(), (span) ->
      spanStrings.push(span.toString())
    "#{spanStrings.join('')}"

module.exports = SpanBuffer