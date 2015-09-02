SpanIndex = require '../../lib/core/span-index'

describe 'SpanIndex', ->
  [spanIndex] = []

  beforeEach ->
    spanIndex = new SpanIndex()

  afterEach ->
    spanIndex.destroy()

  it 'starts empty', ->
    spanIndex.getLength().should.equal(0)
    spanIndex.getSpanCount().should.equal(0)

  it 'is clonable', ->
    spanIndex.insertSpans 0, [
      spanIndex.createSpan('a'),
      spanIndex.createSpan('b'),
      spanIndex.createSpan('c')
    ]
    spanIndex.clone().toString().should.equal('(a)(b)(c)')

  describe 'Text', ->

    it 'insert text into empty adds span if needed', ->
      spanIndex.insertString(0, 'hello world')
      spanIndex.getLength().should.equal(11)
      spanIndex.getSpanCount().should.equal(1)
      spanIndex.toString().should.equal('(hello world)')

    it 'inserts text into correct span', ->
      spanIndex.insertSpans 0, [
        spanIndex.createSpan('a'),
        spanIndex.createSpan('b')
      ]
      spanIndex.insertString(0, 'a')
      spanIndex.toString().should.equal('(aa)(b)')
      spanIndex.insertString(2, 'a')
      spanIndex.toString().should.equal('(aaa)(b)')
      spanIndex.insertString(4, 'b')
      spanIndex.toString().should.equal('(aaa)(bb)')

    it 'removes appropriate spans when text is deleted', ->
      spanIndex.insertSpans 0, [
        spanIndex.createSpan('a'),
        spanIndex.createSpan('b'),
        spanIndex.createSpan('c')
      ]
      sp0 = spanIndex.getSpan(0)
      sp1 = spanIndex.getSpan(1)
      sp2 = spanIndex.getSpan(2)

      spanIndex.deleteRange(0, 1)
      expect(sp0.parent).toBe(null)
      spanIndex.toString().should.equal('(b)(c)')

      spanIndex.deleteRange(1, 1)
      expect(sp2.parent).toBe(null)
      spanIndex.toString().should.equal('(b)')

    it 'delete text to empty deletes last span', ->
      spanIndex.insertString(0, 'hello world')
      spanIndex.deleteRange(0, 11)
      spanIndex.getLength().should.equal(0)
      spanIndex.getSpanCount().should.equal(0)
      spanIndex.toString().should.equal('')

  describe 'Spans', ->

    it 'clones spans', ->
      spanIndex.createSpan('one').getString().should.equal('one')

    it 'inserts spans', ->
      spanIndex.insertSpans 0, [
        spanIndex.createSpan('hello'),
        spanIndex.createSpan(' '),
        spanIndex.createSpan('world')
      ]
      spanIndex.toString().should.equal('(hello)( )(world)')

    it 'removes spans', ->
      spanIndex.insertSpans 0, [
        spanIndex.createSpan('hello'),
        spanIndex.createSpan(' '),
        spanIndex.createSpan('world')
      ]
      spanIndex.removeSpans(1, 2)
      spanIndex.toString().should.equal('(hello)')

    it 'slices spans at text offset ', ->
      spanIndex.insertString(0, 'onetwo')
      spanIndex.sliceSpanAtOffset(0).should.eql(span: spanIndex.getSpan(0), index: 0, startOffset: 0, offset: 0)
      spanIndex.sliceSpanAtOffset(6).should.eql(span: spanIndex.getSpan(0), index: 0, startOffset: 0, offset: 6)
      spanIndex.toString().should.equal('(onetwo)')
      spanIndex.sliceSpanAtOffset(3).should.eql(span: spanIndex.getSpan(0), index: 0, startOffset: 0, offset: 3)
      spanIndex.toString().should.equal('(one)(two)')
      spanIndex.sliceSpanAtOffset(3).should.eql(span: spanIndex.getSpan(0), index: 0, startOffset: 0, offset: 3)

    it 'slice spans to range', ->
      spanIndex.insertString(0, 'onetwo')
      spanIndex.sliceSpansToRange(0, 6).should.eql(index: 0, count: 1)
      spanIndex.sliceSpansToRange(0, 2).should.eql(index: 0, count: 1)
      spanIndex.sliceSpansToRange(4, 2).should.eql(index: 2, count: 1)

    it 'finds spans by text offset', ->
      spanIndex.insertSpans(0, [
        spanIndex.createSpan('one'),
        spanIndex.createSpan('two')
      ])
      spanIndex.getSpanAtOffset(0).should.eql(span: spanIndex.getSpan(0), index: 0, startOffset: 0, offset: 0)
      spanIndex.getSpanAtOffset(2).should.eql(span: spanIndex.getSpan(0), index: 0, startOffset: 0, offset: 2)
      spanIndex.getSpanAtOffset(3).should.eql(span: spanIndex.getSpan(0), index: 0, startOffset: 0, offset: 3)
      spanIndex.getSpanAtOffset(4).should.eql(span: spanIndex.getSpan(1), index: 1, startOffset: 3, offset: 1)
      spanIndex.getSpanAtOffset(5).should.eql(span: spanIndex.getSpan(1), index: 1, startOffset: 3, offset: 2)
      spanIndex.getSpanAtOffset(6).should.eql(span: spanIndex.getSpan(1), index: 1, startOffset: 3, offset: 3)

  describe 'Performance', ->

    it 'should handle 10,000 spans', ->
      console.profile('Create Spans')
      console.time('Create Spans')
      spanCount = 10000
      spans = []
      for i in [0..spanCount - 1]
        spans.push(spanIndex.createSpan('hello world!'))
      console.timeEnd('Create Spans')
      console.profileEnd()

      console.profile('Batch Insert Spans')
      console.time('Batch Insert Spans')
      spanIndex.insertSpans(0, spans)
      spanIndex.getSpanCount().should.equal(spanCount)
      spanIndex.getLength().should.equal(spanCount * 'hello world!'.length)
      console.timeEnd('Batch Insert Spans')
      console.profileEnd()

      console.profile('Batch Remove Spans')
      console.time('Batch Remove Spans')
      spanIndex.removeSpans(0, spanIndex.getSpanCount())
      spanIndex.getSpanCount().should.equal(0)
      spanIndex.getLength().should.equal(0)
      console.timeEnd('Batch Remove Spans')
      console.profileEnd()

      getRandomInt = (min, max) ->
        Math.floor(Math.random() * (max - min)) + min

      console.profile('Random Insert Spans')
      console.time('Random Insert Spans')
      for each in spans
        spanIndex.insertSpans(getRandomInt(0, spanIndex.getSpanCount()), [each])
      spanIndex.getSpanCount().should.equal(spanCount)
      spanIndex.getLength().should.equal(spanCount * 'hello world!'.length)
      console.timeEnd('Random Insert Spans')
      console.profileEnd()

      console.profile('Random Insert Text')
      console.time('Random Insert Text')
      for i in [0..spanCount - 1]
        spanIndex.insertString(getRandomInt(0, spanIndex.getLength()), 'Hello')
      spanIndex.getLength().should.equal(spanCount * 'hello world!Hello'.length)
      console.timeEnd('Random Insert Text')
      console.profileEnd()

      console.profile('Random Access Spans')
      console.time('Random Access Spans')
      for i in [0..spanCount - 1]
        start = getRandomInt(0, spanIndex.getSpanCount())
        end = getRandomInt(start, Math.min(start + 100, spanIndex.getSpanCount()))
        spanIndex.getSpans(start, end - start)
      console.timeEnd('Random Access Spans')
      console.profileEnd()

      console.profile('Random Remove Spans')
      console.time('Random Remove Spans')
      for each in spans
        spanIndex.removeSpans(getRandomInt(0, spanIndex.getSpanCount()), 1)
      spanIndex.getSpanCount().should.equal(0)
      spanIndex.getLength().should.equal(0)
      console.timeEnd('Random Remove Spans')
      console.profileEnd()