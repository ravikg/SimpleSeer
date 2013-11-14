
module.exports = class Pages

  initialize: =>
    @page = {}
    @state = ""

  setPage:(Page) =>
    @close(false)
    @page = new Page
    $(document.body).append( @page.$el )
    @page.render()

  loadPageByName:(name) =>
    view = require "views/pages/#{name}"
    @state = window.location.hash
    if @state is "#page/#{name}"
      @state = "/"
    @setPage(view)
    Application.router.navigate("page/#{name}")

  close:(navigate=true) =>
    @page._close?()
    if navigate
      Application.router.navigate(@state, {trigger: true})
