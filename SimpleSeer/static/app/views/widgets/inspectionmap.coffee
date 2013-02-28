SubView = require 'views/core/subview'
template = require './templates/inspectionmap'
application = require 'application'

module.exports = class inspectionMap extends SubView
	template: template

	mergeCamera: =>		
		_.each @model.attributes.results, (result, id) =>
			@model.attributes.results[id].camera = SimpleSeer.settings.cameras[id]

	getRenderData: =>	
		@mergeCamera()
		final = []; maps = []; fails = {}
		_.each @model.attributes.results, (result) =>
			maps.push result.camera.map
			console.log result
			if result.string is "FAIL"
				console.log result.camera.map, result.camera.name
				fails[result.camera.map] = 1

		_.each _.uniq(maps), (map) =>
			final.push {name: map, pass: (if fails[map] == 1 then "fail" else "pass")}

		return {
			model: @model
			maps: final
		}
