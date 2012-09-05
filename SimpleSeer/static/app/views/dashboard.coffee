template = require './templates/dashboard'
application = require '../application'
Tab = require '.tab_view'

module.exports = class Dashboard extends Tab
  building:false
  
  initialize: () =>
    #load or create collection from server
    #cycle through, and @addGraph(new graph)
    super()
    
  createGraph: =>
    #create graph from settings
    #graph = new GraphView
    #graph.save()
    @addGraph(graph)
        
  addGraph: (graph) =>
    #add div to grid
    #draw graph to div
    #if graph.id not in collection, collection.add and save
    
  toggleBuilder: =>
    @building =  !@building
    controls = @$el.find('#graphBuilderControls')
    preview =  @$el.find('#graphBuilderPreview')
    if @building
      #reset builder controls

      #slide in builders
      controls.show("slide", { direction: "right" })
      preview.show("slide", { direction: "left" })
    else
      #slide out builders
      controls.hide("slide", { direction: "left" }, -300)
      preview.hide("slide", { direction: "right" }, 10000)
    