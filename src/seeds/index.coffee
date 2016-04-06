Imm = require 'immutable'
Faker = require 'faker'
Async = require 'async'
Moment = require 'moment'

{Users, Persist, generateId} = require '../persist'
Create = require './create'

generateClientFiles = (quantity, metrics, cb) ->
	clientFile = null
	planTargets = null
	sections = null
	targetIds = null

	Async.timesSeries quantity, (quantityPosition, cb) ->
		console.log "About to generate clientFile ##{quantityPosition}"

		Async.series [
			# Create the empty clientFile
			(cb) ->
				Create.clientFile (err, result) ->
					if err
						cb err
						return

					clientFile = result
					console.log "Created clientFile", clientFile.toJS()
					cb()

			# Create planTargets
			(cb) ->
				Create.planTargets 5, {clientFile, metrics}, (err, results) ->
					if err
						cb err
						return

					planTargets = results
					console.log "Created planTargets", planTargets.toJS()
					cb()

			# Apply the target to a section, apply to clientFile, save
			(cb) ->
				targetIds = planTargets
				.map (target) -> target.get('id')
				.toJS()

				section = {
					id: generateId()
					name: "Aggression Section"
					targetIds
				}

				sections = [section]

				console.log "Sections to add:", sections

				clientFile = clientFile.setIn(['plan', 'sections'], sections)

				global.ActiveSession.persist.clientFiles.createRevision clientFile, (err, result) ->
					if err
						cb err
						return

					clientFile = result
					console.log "Modified clientFile with sections:", clientFile.toJS()
					cb()

			# Write a progNote, write a note and random metric for each target, in each section
			(cb) ->
				# 1. Loop over clientFile's sections
				# clientFile.plan.sections.each(section)
				# 	sectionId = section.get('id')

				# 2. Loop over sections' targetIds
					# section.targetsIds.each(targetId)
						

				# 3. Get target with corresponding ID
						# target = .getElementById(targetId)
				
				# 4. Record the note for the target
					# done in Create.progNote

				# 5. Record a random number for each metric 
					# done in Create.progNote

				# 6. Save the progNote
					# clientFile = clientFile.setIn([])
					# or?
						Create.progNotes 3, {clientFile, sectionId, targetIds, metrics}, cb
							if err
								cb err
								return

							progNotes = results
							console.log "Created progNotes", progNotes.toJS()
							cb()
				
				cb()


		], (err) ->
			if err
				cb err
				return

			console.log "Done with clientFile ##{quantityPosition}"
			cb(null, clientFile)

	, (err, results) ->
		if err
			cb err
			return

		clientFiles = Imm.List(results)
		cb(null, clientFiles)


runSeries = ->
	clientFiles = null
	programs = null
	links = null
	metrics = null
	eventTypes = null
	accounts = null
	quickNotes = null
	planTargets = null

	Async.series [
		(cb) ->
			Create.accounts 0, (err, results) ->
				if err
					cb err
					return

				accounts = results
				cb()

		(cb) ->
			Create.programs 2, (err, results) ->
				if err
					cb err
					return

				programs = results
				cb()		

		(cb) ->
			Create.eventTypes 1, (err, results) ->
				if err
					cb err
					return

				eventTypes = results
				cb()		

		(cb) ->
			Create.metrics 4, (err, results) ->
				if err
					cb err
					return

				metrics = results
				cb()

		(cb) ->
			generateClientFiles 2, metrics, (err, results) ->
				if err
					cb err
					return

				clientFiles = results
				console.log "DONE! clientFiles generated:", clientFiles.toJS()
				cb()


		# (cb) ->
		# 	Async.map programs.toArray(), (program, cb) ->
		# 		Create.clientFileProgramLinks clientFiles, program, (err, result) ->
		# 			if err 
		# 				cb err
		# 				return

		# 			cb null, Imm.List(result)
		# 	, (err, result) ->
		# 		if err
		# 			cb err
		# 			return

		# 		links = Imm.List(result)
		# 		cb()




	], (err) ->
		if err
			console.error err
			return




module.exports = {
	
	runSeries

}

