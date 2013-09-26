[Template, SubView, application] = [
  require("views/widgets/templates/metadataeditor"),
  require("views/core/subview"),
  require("application")
]

module.exports = class Metadata extends SubView
  template: Template
  className: 'menu-widget metaeditor'
  
  events: =>
    'change input':'editMeta'
    'change textarea':'editNotes'

  editMeta:(eve) =>
    el = $(eve.currentTarget)
    @model.attributes.metadata[el.attr('name')] = el.val()
    @model.save()
    application.alert('Information saved', 'success')
    $('#messages .alert').last().delay(3000).fadeOut('fast');
    
  editNotes:(eve) =>
    el = $(eve.currentTarget)
    @model.attributes.metadata['Notes'] = el.val()
    @model.save()
    application.alert('Information saved', 'success')
    $('#messages .alert').last().delay(3000).fadeOut('fast');
    
  setModel:(model) =>
    @model = model
    @render()

  render:=>
    if @options.parent.active
      return super()

  getRenderData:=>
    retVal = {}
    if @model
      md = []
      metadata = @model.get('metadata')
      if metadata
        for field in @options.params.fields
          if field != 'Notes'
            md.push {key:field,value:metadata[field]}
            #md[field] = metadata[field]
        retVal = {metadata:md, notes:metadata['Notes']}
    return retVal
    