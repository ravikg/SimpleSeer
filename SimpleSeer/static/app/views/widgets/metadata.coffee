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
  key: 'id'
  blacklist: ['tolstate', 'type', 'workorder']

  events: =>
    "click .notes .add": "toggleNotes"
    "click .notes img": "toggleNotes"
    "click .notes .sac": "saveNoteAndClose"
    "click [data-action=edit]": "editMeta"

  select: (params) =>
    if params and params[@key]?
      @selected = params[@key]
      @frame = @_getFrame(@frames)
      @render()

  receive: (data) =>
    @frames = data
    frame = @_getFrame(@frames)
    if !@frame or @frame.get('id') != frame.get('id')
      @frame = frame
      @render()

  _getFrame: (frames, i=null) =>
    frame = null
    if i != null
      frame = frames[i]
    else if @selected
      for o,i in frames
        if o.get(@key) is String(@selected)
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
    fields = []
    if frame
      for i,o of frame.get('metadata')
        if not (i in @blacklist)
          if i == 'datetime'
            o = moment(o).format('MM/DD/YYYY HH:mm:ss')
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
    @frame.attributes.notes = @$("textarea").val()
    @frame.save()
    @$(".notes").removeClass("expanded")
    @$(".notes-editor").hide()
    @render()

  editMeta: =>
    Application.modal.show()
    #setTimeout(Application.modal.clear, 3000)
