# The Plan tab on the client file page.

Async = require 'async'
Imm = require 'immutable'
Moment = require 'moment'

Config = require '../config'
Persist = require '../persist'

load = (win) ->
	$ = win.jQuery
	Bootbox = win.bootbox
	React = win.React
	R = React.DOM
	CrashHandler = require('../crashHandler').load(win)
	ExpandingTextArea = require('../expandingTextArea').load(win)
	MetricLookupField = require('../metricLookupField').load(win)
	MetricWidget = require('../metricWidget').load(win)
	PrintButton = require('../printButton').load(win)
	{FaIcon, renderLineBreaks, showWhen, stripMetadata} = require('../utils').load(win)

	PlanView = React.createFactory React.createClass
		mixins: [React.addons.PureRenderMixin]

		getInitialState: ->
			return {
				plan: @props.plan
				selectedTargetId: null
				currentTargetRevisionsById: @_generateCurrentTargetRevisionsById @props.planTargetsById
			}

		componentWillReceiveProps: (newProps) ->
			# Regenerate transient data when plan is updated
			unless Imm.is(newProps.plan, @props.plan)
				@setState {
					plan: newProps.plan
					currentTargetRevisionsById: @_generateCurrentTargetRevisionsById @props.planTargetsById
				}

		_generateCurrentTargetRevisionsById: (planTargetsById) ->
			return planTargetsById.mapEntries ([targetId, target]) =>
				latestRev = stripMetadata target.get('revisions').first()
				return [targetId, latestRev]

		render: ->
			plan = @state.plan

			# If something selected and that target has not been deleted
			if @state.selectedTargetId? and @state.currentTargetRevisionsById.has(@state.selectedTargetId)
				# If this target has been saved at least once
				if @props.planTargetsById.has @state.selectedTargetId
					selectedTarget = @props.planTargetsById.get @state.selectedTargetId
				else
					# New target with no revision history
					selectedTarget = Imm.fromJS {
						id: @state.selectedTargetId
						revisions: []
					}
			else
				selectedTarget = null

			return R.div({className: "view planView #{if @props.isVisible then '' else 'hide'}"},
				R.div({className: 'targetList'},
					R.div({className: "empty #{showWhen plan.get('sections').size is 0}"},
						R.div({className: 'message'},
							"This client does not currently have any plan targets."
						)						
						R.button({
							className: 'addSection btn btn-success btn-lg'
							onClick: @_addSection
						},
							FaIcon('plus')
							"Add section"
						)
					)
					R.div({className: "toolbar #{showWhen plan.get('sections').size > 0}"},
						R.span({className: 'leftMenu'},
							R.button({
								className: [
									'save btn'
									'btn-' + if @hasChanges() then 'success canSave' else 'warning'
								].join ' '
								disabled: not @hasChanges()
								onClick: @_save
							},
								FaIcon('save')
								if @hasChanges() then "Save Plan" else "No Changes to Save"
							)	
						)
						R.span({className: 'rightMenu'},							
							R.button({
								className: 'addSection btn btn-default'
								onClick: @_addSection
							},
								FaIcon('plus')
								"Add section"
							)
							PrintButton({
								dataSet: [
									{
										format: 'plan'
										data: {
											sections: plan.get('sections')
											targets: @state.currentTargetRevisionsById
											metrics: @props.metricsById
										}
										clientFile: @props.clientFile
									}
								]
								isVisible: not @hasChanges()
								iconOnly: true
							})					
						)
					)
					R.div({className: 'sections'},
						(plan.get('sections').map (section) =>
							R.div({className: 'section', key: section.get('id')},
								R.div({className: 'sectionHeader'},
									R.div({className: 'sectionName'},
										section.get('name')
									)
									R.button({
										className: 'addTarget btn btn-sm btn-primary'
										onClick: @_addTargetToSection.bind null, section.get('id')
									},
										FaIcon('plus')
										'Add target'
									)
								)
								(if section.get('targetIds').size is 0
									R.div({className: 'noTargets'},
										"This section is empty."
									)
								)
								R.div({className: 'targets'},
									(section.get('targetIds').map (targetId) =>
										PlanTarget({
											currentRevision: @state.currentTargetRevisionsById.get targetId
											metricsById: @props.metricsById
											hasTargetChanged: @_hasTargetChanged targetId
											key: targetId
											isActive: targetId is @state.selectedTargetId
											onTargetUpdate: @_updateTarget.bind null, targetId
											onTargetSelection: @_setSelectedTarget.bind null, targetId
										})
									).toJS()...
								)
							)
						).toJS()...
					)
				)
				R.div({className: 'targetDetail'},
					(if selectedTarget is null
						R.div({className: "noSelection #{showWhen plan.get('sections').size > 0}"},
							"More information will appear here when you select ",
							"a target on the left."
						)
					else
						currentRev = @state.currentTargetRevisionsById.get(selectedTarget.get('id'))
						metricDefs = currentRev.get('metricIds').map (metricId) =>
							return @props.metricsById.get(metricId, null)

						R.div({className: 'targetDetailContainer'},
							R.div({className: 'metricsSection'},
								R.div({className: 'header'},
									R.div({className: 'text'}, 'Metrics')
								)
								(if metricDefs.size is 0
									R.div({className: 'noMetrics'},
										"This target has no metrics attached. "
										R.button({
											className: 'btn btn-link addMetricButton'
											onClick: @_focusMetricLookupField
										}, FaIcon('plus'))
									)									
								)
								R.div({className: 'metrics'},
									(metricDefs.map (metricDef) =>
										MetricWidget({
											isEditable: false
											allowDeleting: true
											onDelete: @_deleteMetricFromTarget.bind(
												null, selectedTarget.get('id'), metricDef.get('id')
											)
											key: metricDef.get('id')
											name: metricDef.get('name')
											definition: metricDef.get('definition')
										})
									).toJS()...
									(if metricDefs.size > 0
										R.button({
											className: 'btn btn-link addMetricButton'
											onClick: @_focusMetricLookupField
										}, FaIcon('plus'))
									)
								)
								R.div({},
									MetricLookupField({
										metrics: @props.metricsById.valueSeq()
										onSelection: @_addMetricToTarget.bind(
											null, selectedTarget.get('id')
										)
										placeholder: "Find / Define a Metric"
									})
								)
							)
							R.div({className: 'history'},
								R.div({className: 'heading'},
									'History'
								)
								(if selectedTarget.get('revisions').size is 0
									R.div({className: 'noRevisions'},
										"This target is new.  ",
										"It won't have any history until the client file is saved."
									)
								)
								R.div({className: 'revisions'},
									(selectedTarget.get('revisions').map (rev) =>
										R.div({className: 'revision'},
											R.div({className: 'nameLine'},
												R.div({className: 'name'},
													rev.get('name')
												)
												R.div({className: 'tag'},
													Moment(rev.get('timestamp'), Persist.TimestampFormat)
														.format('MMM D, YYYY [at] HH:mm'),
													" by ",
													rev.get('author')
												)
											)
											R.div({className: 'notes'},
												renderLineBreaks rev.get('notes')
											)
										)
									).toJS()...
								)
							)
						)
					)
				)
			)

		_focusMetricLookupField: -> $('.lookupField').focus()

		blinkUnsaved: ->			
			toggleBlink = -> $('.hasChanges').toggleClass('blink')
			secondBlink = ->
				toggleBlink()
				setTimeout(toggleBlink, 500)

			setTimeout(secondBlink, 750)

		hasChanges: ->
			# If there is a difference, then there have been changes
			unless Imm.is @props.plan, @state.plan
				return true

			for targetId in @state.currentTargetRevisionsById.keySeq().toJS()
				if @_hasTargetChanged targetId
					return true

			return false
		_hasTargetChanged: (targetId) ->
			currentRev = @_normalizeTarget @state.currentTargetRevisionsById.get(targetId)

			# If this is a new target
			target = @props.planTargetsById.get(targetId, null)
			unless target
				# If target is empty
				emptyName = currentRev.get('name') is ''
				emptyNotes = currentRev.get('notes') is ''
				if emptyName and emptyNotes
					return false

				return true

			lastRev = target.getIn ['revisions', 0]

			lastRevNormalized = lastRev
				.delete('revisionId')
				.delete('author')
				.delete('timestamp')
			unless Imm.is(currentRev, lastRevNormalized)
				return true

			return false

		_save: ->
			@_normalizeTargets()
			@_removeUnusedTargets()

			# Wait for state changes to be applied
			@forceUpdate =>
				valid = @_validateTargets()

				unless valid
					Bootbox.alert 'Cannot save plan: there are empty target fields.'
					return

				newPlanTargets = @state.currentTargetRevisionsById.valueSeq()
				.filter (target) =>
					# Only include targets that have not been saved yet
					return not @props.planTargetsById.has(target.get('id'))
				.map(@_normalizeTarget)

				updatedPlanTargets = @state.currentTargetRevisionsById.valueSeq()
				.filter (target) =>
					# Ignore new targets
					unless @props.planTargetsById.has(target.get('id'))
						return false

					# Only include targets that have actually changed
					return @_hasTargetChanged target.get('id')
				.map(@_normalizeTarget)

				@props.updatePlan @state.plan, newPlanTargets, updatedPlanTargets

		_normalizeTargets: ->
			@setState (state) =>
				return {
					currentTargetRevisionsById: state.currentTargetRevisionsById
					.map (targetRev, targetId) =>
						return @_normalizeTarget targetRev
				}

		_normalizeTarget: (targetRev) ->
			trim = (s) -> s.trim()

			# Trim whitespace from fields
			return targetRev
			.update('name', trim)
			.update('notes', trim)

		_removeUnusedTargets: ->
			@setState (state) =>
				unusedTargetIds = state.plan.get('sections').flatMap (section) =>
					return section.get('targetIds').filter (targetId) =>
						currentRev = state.currentTargetRevisionsById.get(targetId)

						emptyName = currentRev.get('name') is ''
						emptyNotes = currentRev.get('notes') is ''
						noMetrics = currentRev.get('metricIds').size is 0
						noHistory = @props.planTargetsById.get(targetId, null) is null

						return emptyName and emptyNotes and noMetrics and noHistory

				return {
					plan: state.plan.update 'sections', (sections) =>
						return sections.map (section) =>
							return section.update 'targetIds', (targetIds) =>
								return targetIds.filter (targetId) =>
									return not unusedTargetIds.contains(targetId)

					currentTargetRevisionsById: state.currentTargetRevisionsById
					.filter (rev, targetId) =>
						return not unusedTargetIds.contains(targetId)
				}

		_validateTargets: -> # returns true iff all valid
			return @state.plan.get('sections').every (section) =>
				return section.get('targetIds').every (targetId) =>
					currentRev = @state.currentTargetRevisionsById.get(targetId)

					emptyName = currentRev.get('name') is ''
					emptyNotes = currentRev.get('notes') is ''

					return not emptyName and not emptyNotes

		_addSection: ->
			sectionId = Persist.generateId()

			Bootbox.prompt 'Enter a name for the new section:', (sectionName) =>
				sectionName = sectionName?.trim()

				unless sectionName
					return

				newPlan = @state.plan.update 'sections', (sections) =>
					return sections.push Imm.fromJS {
						id: sectionId
						name: sectionName
						targetIds: []
					}

				@setState {plan: newPlan}, =>
					@_addTargetToSection sectionId
		_addTargetToSection: (sectionId) ->
			sectionIndex = @_getSectionIndex sectionId

			targetId = '__transient__' + Persist.generateId()
			newPlan = @state.plan.updateIn ['sections', sectionIndex, 'targetIds'], (targetIds) =>
				return targetIds.push targetId

			newTarget = Imm.fromJS {
				id: targetId
				clientFileId: @props.clientFileId
				name: ''
				notes: ''
				metricIds: []
			}
			newCurrentRevs = @state.currentTargetRevisionsById.set targetId, newTarget

			@setState {
				plan: newPlan
				currentTargetRevisionsById: newCurrentRevs
			}, =>
				$(".target-#{targetId} .name.field").focus()
		_getSectionIndex: (sectionId) ->
			return @state.plan.get('sections').findIndex (section) =>
				return section.get('id') is sectionId
		_updateTarget: (targetId, newValue) ->
			@setState {
				currentTargetRevisionsById: @state.currentTargetRevisionsById.set targetId, newValue
			}
		_setSelectedTarget: (targetId) ->
			@setState {selectedTargetId: targetId}

		_addMetricToTarget: (targetId, metricId) ->			
			# Current target already has this metric
			if @state.currentTargetRevisionsById.getIn([targetId, 'metricIds']).contains metricId
				Bootbox.alert "This metric has already been added to the selected target."
				return

			# Metric exists in another target
			existsElsewhere = @state.currentTargetRevisionsById.some (target) =>
				return target.get('metricIds').contains(metricId)
			if existsElsewhere
				Bootbox.alert "This metric already exists for another plan target"
				return

			@setState {
				currentTargetRevisionsById: @state.currentTargetRevisionsById.update targetId, (currentRev) ->
					return currentRev.update 'metricIds', (metricIds) ->
						return metricIds.push metricId
			}

		_deleteMetricFromTarget: (targetId, metricId) ->
			@setState {
				currentTargetRevisionsById: @state.currentTargetRevisionsById.update targetId, (currentRev) ->
					return currentRev.update 'metricIds', (metricIds) ->
						return metricIds.filter (id) ->
							return id isnt metricId
			}

	PlanTarget = React.createFactory React.createClass
		mixins: [React.addons.PureRenderMixin]

		render: ->
			currentRevision = @props.currentRevision

			return R.div({
				className: [
					'target'
					"target-#{@props.key}"
					if @props.isActive then 'active' else ''
					if @props.hasTargetChanged then 'hasChanges' else ''
				].join ' '
				onClick: @_onTargetClick
			},
				R.div({className: 'nameContainer'},
					R.input({
						type: 'text'
						className: 'name field form-control'
						ref: 'nameField'
						value: currentRevision.get('name')
						onChange: @_updateField.bind null, 'name'
						onFocus: @props.onTargetSelection
					})
				)
				R.div({className: 'notesContainer'},
					ExpandingTextArea({
						className: 'notes field'
						ref: 'notesField'
						value: currentRevision.get('notes')
						onChange: @_updateField.bind null, 'notes'
						onFocus: @props.onTargetSelection
					})
				)
				R.div({className: 'metrics'},
					(currentRevision.get('metricIds').map (metricId) =>
						metric = @props.metricsById.get(metricId)

						MetricWidget({
							name: metric.get('name')
							definition: metric.get('definition')
							value: metric.get('value')
							key: metricId
						})
					).toJS()...
				)
			)
		_updateField: (fieldName, event) ->
			newValue = @props.currentRevision.set fieldName, event.target.value
			@props.onTargetUpdate newValue
		_onTargetClick: (event) ->
			unless event.target.classList.contains 'field'
				@refs.nameField.getDOMNode().focus()

	return {PlanView}

module.exports = {load}
