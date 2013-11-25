[ SubView, Template, Model ] = [
  require("views/subview"),
  require("./templates/metadata")
  require("models/frame")
]

module.exports = class MetaData extends SubView
  template: Template
  selected: null
  frames: []
  frame: null

  # TODO: TPM, VIN may need to be at the front
  # of the metabar according to Jackie. Be concious
  # of this moving forward.

  # TODO: Put in YAML
  key: 'tpm'
  blacklist: ['tolstate', 'type']

  events: =>
    "click .notes .add": "toggleNotes"
    "click .notes img": "toggleNotes"
    "click .notes .sac": "saveNoteAndClose"

  select: (params) =>
    if params and params[@key]?
      @selected = params[@key]
      @frame = @_getFrame(@frames)
      @render()

  receive: (data) =>
    @frames = data
    @frame = @_getFrame(@frames)
    @render()

  _getFrame: (frames) =>
    frame = null
    if @selected
      for o,i in frames
        md = o.get('metadata')
        if String(md[@key]) is String(@selected)
          frame = o
          break
    else
      frame = frames[0]
    return frame

  _keySort: (a,b) =>
    if a.key < b.key
       return -1
    if a.key > b.key
      return 1
    return 0

  # THIS FUNCTION WOULD BE OVERWRITTEN BY YAML CONFIG --
  # i.e. The user could specify exact fields to use and in which order
  _format: (frame) =>
    console.dir(frame)
    fields = []
    if frame
      for i,o of frame.get('metadata')
        if not (i in @blacklist)
          fields.push({'key':i, 'value':o})
    fields.sort(@_keySort)
    return fields

  getRenderData: =>
    fields: @_format(@frame)
    notes: @frame?.get("notes")

  toggleNotes: =>
    @$(".notes").toggleClass("expanded")
    if @$(".notes").hasClass("expanded")
      @$(".notes-editor").show()
    else 
      @$(".notes-editor").hide()

  saveNoteAndClose: =>
    console.log @frame.get("notes")
    @frame.set("notes", @$("textarea").html())
    @frame?.save()
    console.log @frame.get("notes")
    @$(".notes").removeClass("expanded")
    @$(".notes-editor").hide()
    @render()
