[ SubView, Template ] = [
  require("views/subview"),
  require("./templates/frames")
]

module.exports = class FramesView extends SubView
  template: Template

  events: =>
    'click [data-widget=SideBar] .header': @_slide

  _slide: (e) =>
    @afterRender()

  afterRender: =>
    @$el.find('.content-wrapper').css('left', (if @$el.find('[data-widget=SideBar]').width() then @$el.find('[data-widget=SideBar]').width() + 1 else 0 ))