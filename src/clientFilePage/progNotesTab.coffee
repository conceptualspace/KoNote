# Copyright (c) Konode. All rights reserved.
# This source code is subject to the terms of the Mozilla Public License, v. 2.0 
# that can be found in the LICENSE file or at: http://mozilla.org/MPL/2.0

Assert = require 'assert'
Imm = require 'immutable'
Moment = require 'moment'

Config = require '../config'
Term = require '../term'
Persist = require '../persist'

load = (win) ->
	$ = win.jQuery
	Bootbox = win.bootbox
	React = win.React
	R = React.DOM
	
	CancelProgNoteDialog = require('./cancelProgNoteDialog').load(win)
	CrashHandler = require('../crashHandler').load(win)
	ExpandingTextArea = require('../expandingTextArea').load(win)
	MetricWidget = require('../metricWidget').load(win)
	OpenDialogLink = require('../openDialogLink').load(win)
	ProgEventsWidget = require('../progEventsWidget').load(win)
	ProgNoteDetailView = require('../progNoteDetailView').load(win)
	PrintButton = require('../printButton').load(win)
	WithTooltip = require('../withTooltip').load(win)
	{FaIcon, openWindow, renderLineBreaks, showWhen
	getUnitIndex, getPlanSectionIndex, getPlanTargetIndex} = require('../utils').load(win)

	ProgNotesView = React.createFactory React.createClass
		displayName: 'ProgNotesView'
		mixins: [React.addons.PureRenderMixin]

		getInitialState: -> {
			editingProgNoteId: null
		}

		getInitialState: ->
			return {
				selectedItem: null
				highlightedProgNoteId: null
				highlightedTargetId: null
				backdate: ''
				revisingProgNote: null
			}

		componentDidMount: ->
			progNotesPane = $('.progNotes')
			progNotesPane.on 'scroll', =>
				if @props.isLoading is false and @props.headerIndex < @props.progNoteTotal
					if progNotesPane.scrollTop() + progNotesPane.innerHeight() + progNotesPane.innerHeight() >= progNotesPane[0].scrollHeight
						@props.renewAllData()
			
			quickNoteToggle = $('.addQuickNote')
			quickNoteToggle.data 'isVisible', false
			quickNoteToggle.popover {
				placement: 'bottom'
				html: true
				trigger: 'manual'
				content: '''
					<textarea class="form-control"></textarea>
					<div class="buttonBar form-inline">
						<label>Date: </label> <input type="text" class="form-control backdate date"></input>
						<button class="cancel btn btn-danger"><i class="fa fa-trash"></i> Discard</button>
						<button class="save btn btn-primary"><i class="fa fa-check"></i> Save</button>
					</div>
				'''
			}

		render: ->
			progNoteHistories = @props.progNoteHistories

			# Only show the single progNote while editing
			if @state.revisingProgNote?
				progNoteHistories = progNoteHistories.filter (progNoteHistory) =>
					progNote = progNoteHistory.last()
					return progNote.get('id') is @state.revisingProgNote.get('id')

			return R.div({className: "view progNotesView #{showWhen @props.isVisible}"},
				R.div({className: "toolbar #{showWhen @props.progNoteHistories.size > 0}"},
					(if @state.revisingProgNote?
						R.div({},
							R.button({
								className: 'btn btn-success saveRevisingProgNote'
								onClick: @_saveProgNoteRevision
							},
								FaIcon 'save'
								"Save Changes"
							)
							R.button({
								className: 'btn btn-link cancelRevisingProgNote'
								onClick: @_cancelRevisingProgNote
							},
								"Cancel"
							)
						)
					else
						R.div({},
							R.button({
								className: 'newProgNote btn btn-primary'
								onClick: @_openNewProgNote
								disabled: @props.isReadOnly
							},
								FaIcon 'file'
								"New #{Term 'progress note'}"
							)
							R.button({
								className: "addQuickNote btn btn-default #{showWhen @props.progNoteHistories.size > 0}"						
								onClick: @_toggleQuickNotePopover
								disabled: @props.isReadOnly
							},
								FaIcon 'plus'
								"Add #{Term 'quick note'}"
							)
						)
					)
				)
				R.div({className: 'panes'},
					R.div({
						className: 'progNotes'
						ref: 'progNotes'
					},
						R.div({className: "empty #{showWhen @props.progNoteHistories.size is 0}"},
							R.div({className: 'message'},
								"This #{Term 'client'} does not currently have any #{Term 'progress notes'}."
							)
							R.button({
								className: 'btn btn-primary btn-lg newProgNote'
								onClick: @_openNewProgNote
								disabled: @props.isReadOnly
							},
								FaIcon 'file'
								"New #{Term 'progress note'}"
							)
							R.button({
								className: "btn btn-default btn-lg addQuickNote #{showWhen @props.progNoteHistories.size is 0}"								
								onClick: @_toggleQuickNotePopover
								disabled: @props.isReadOnly
							},
								FaIcon 'plus'
								"Add #{Term 'quick note'}"
							)
						)
						(progNoteHistories.map (progNoteHistory) =>
							progNote = progNoteHistory.last()
							progNoteId = progNote.get('id')

							isEditing = @state.revisingProgNote? and @state.revisingProgNote.get('id') is progNoteId

							# Filter out only events for this progNote
							progEvents = @props.progEvents.filter (progEvent) =>
								return progEvent.get('relatedProgNoteId') is progNote.get('id')

							if progNote.get('status') is 'cancelled'
								return CancelledProgNoteView({
									key: progNote.get('id')
									progNoteHistory
									progEvents
									eventTypes: @props.eventTypes
									clientFile: @props.clientFile
									setSelectedItem: @_setSelectedItem
									selectedItem: @state.selectedItem
								})

							Assert.equal progNote.get('status'), 'default'

							switch progNote.get('type')
								when 'basic'
									QuickNoteView({
										key: progNote.get('id')
										progNote
										clientFile: @props.clientFile										
										selectedItem: @state.selectedItem
										setHighlightedQuickNoteId: @_setHighlightedQuickNoteId
										setSelectedItem: @_setSelectedItem
										isReadOnly: @props.isReadOnly

										isEditing
										revisingProgNote: @state.revisingProgNote
										startRevisingProgNote: @_startRevisingProgNote
										cancelRevisingProgNote: @_cancelRevisingProgNote
										updateBasicUnitNotes: @_updateBasicUnitNotes
										saveProgNoteRevision: @_saveProgNoteRevision
									})
								when 'full'
									ProgNoteView({
										key: progNote.get('id')
										progNote
										progEvents
										eventTypes: @props.eventTypes
										clientFile: @props.clientFile
										setSelectedItem: @_setSelectedItem
										setEditingProgNoteId: @_setEditingProgNoteId
										updatePlanTargetNotes: @_updatePlanTargetNotes
										setHighlightedProgNoteId: @_setHighlightedProgNoteId
										setHighlightedTargetId: @_setHighlightedTargetId
										selectedItem: @state.selectedItem
										isReadOnly: @props.isReadOnly

										isEditing
										revisingProgNote: @state.revisingProgNote
										startRevisingProgNote: @_startRevisingProgNote
										cancelRevisingProgNote: @_cancelRevisingProgNote
										updateBasicUnitNotes: @_updateBasicUnitNotes
										updatePlanTargetNotes: @_updatePlanTargetNotes
										saveProgNoteRevision: @_saveProgNoteRevision
									})
								else
									throw new Error "unknown prognote type: #{progNote.get('type')}"
						).toJS()...
					)
					ProgNoteDetailView({
						item: @state.selectedItem
						highlightedProgNoteId: @state.highlightedProgNoteId
						highlightedQuickNoteId: @state.highlightedQuickNoteId
						highlightedTargetId: @state.highlightedTargetId
						progNoteHistories: @props.progNoteHistories
						progEvents: @props.progEvents
						eventTypes: @props.eventTypes
					})
				)
			)

		_startRevisingProgNote: (revisingProgNote) ->
			@setState {revisingProgNote}

		_cancelRevisingProgNote: ->
			@setState {revisingProgNote: null}

		_updateBasicUnitNotes: (unitId, event) ->
			newNotes = event.target.value

			unitIndex = getUnitIndex @state.revisingProgNote, unitId

			@setState {
				revisingProgNote: @state.revisingProgNote.setIn(
					[
						'units', unitIndex
						'notes'
					]
					newNotes
				)
			}

		_updatePlanTargetNotes: (unitId, sectionId, targetId, event) ->
			newNotes = event.target.value

			unitIndex = getUnitIndex @state.revisingProgNote, unitId
			sectionIndex = getPlanSectionIndex @state.revisingProgNote, unitIndex, sectionId
			targetIndex = getPlanTargetIndex @state.revisingProgNote, unitIndex, sectionIndex, targetId

			@setState {
				revisingProgNote: @state.revisingProgNote.setIn(
					[
						'units', unitIndex
						'sections', sectionIndex
						'targets', targetIndex
						'notes'
					]
					newNotes
				)
			}

		_saveProgNoteRevision: ->
			@props.setIsLoading true

			progNoteRevision = @state.revisingProgNote

			console.log "progNoteRevision", progNoteRevision.toJS()

			ActiveSession.persist.progNotes.createRevision progNoteRevision, (err, result) =>
				@props.setIsLoading false

				if err
					if err instanceof Persist.IOError
						Bootbox.alert """
							An error occurred.  Please check your network connection and try again.
						"""
						return

					CrashHandler.handle err
					return

				@_cancelRevisingProgNote()
				Bootbox.alert "Successfully revised #{Term 'progress note'}!"
				return

		_setHighlightedProgNoteId: (highlightedProgNoteId) ->
			@setState {highlightedProgNoteId}

		_setHighlightedQuickNoteId: (highlightedQuickNoteId) ->	
			@setState {highlightedQuickNoteId}

		_setHighlightedTargetId: (highlightedTargetId) ->
			@setState {highlightedTargetId}

		_openNewProgNote: ->
			if @props.hasChanges()
				Bootbox.dialog {
					title: "Unsaved Changes to #{Term 'Plan'}"
					message: """
						You have unsaved changes in the #{Term 'plan'} that will not be reflected in this
						#{Term 'progress note'}. How would you like to proceed?
					"""
					buttons: {
						default: {
							label: "Cancel"
							className: "btn-default"
							callback: => Bootbox.hideAll()
						}
						danger: {
							label: "Ignore"
							className: "btn-danger"
							callback: => 
								openWindow {page: 'newProgNote', clientFileId: @props.clientFileId}
						}
						success: {
							label: "View #{Term 'Plan'}"
							className: "btn-success"
							callback: => 
								Bootbox.hideAll()
								@props.onTabChange 'plan'
						}
					}
				}
			else
				@props.setIsLoading true

				openWindow {
					page: 'newProgNote'
					clientFileId: @props.clientFileId
				}

				global.ActiveSession.persist.eventBus.once 'newProgNotePage:loaded', =>
					@props.setIsLoading false

		_toggleQuickNotePopover: ->
			quickNoteToggle = $('.addQuickNote:not(.hide)')

			if quickNoteToggle.data('isVisible')
				quickNoteToggle.popover('hide')
				quickNoteToggle.data('isVisible', false)
			else
				global.document = win.document
				quickNoteToggle.popover('show')
				quickNoteToggle.data('isVisible', true)

				popover = quickNoteToggle.siblings('.popover')
				popover.find('.save.btn').on 'click', (event) =>
					event.preventDefault()

					@props.createQuickNote popover.find('textarea').val(), @state.backdate, (err) =>
						@setState {backdate: ''}
						if err
							if err instanceof Persist.IOError
								Bootbox.alert """
									An error occurred.  Please check your network connection and try again.
								"""
								return

							CrashHandler.handle err
							return

						quickNoteToggle.popover('hide')
						quickNoteToggle.data('isVisible', false)

				popover.find('.backdate.date').datetimepicker({
					format: 'MMM-DD-YYYY h:mm A'
					defaultDate: Moment()
					maxDate: Moment()
					widgetPositioning: {
						vertical: 'bottom'
					}
				}).on 'dp.change', (e) =>
					if Moment(e.date).format('YYYY-MM-DD-HH') is Moment().format('YYYY-MM-DD-HH')
						@setState {backdate: ''}
					else
						@setState {backdate: Moment(e.date).format(Persist.TimestampFormat)}
				
				popover.find('.cancel.btn').on 'click', (event) =>
					event.preventDefault()
					@setState {backdate: ''}
					quickNoteToggle.popover('hide')
					quickNoteToggle.data('isVisible', false)

				popover.find('textarea').focus()

		_setSelectedItem: (selectedItem) ->
			@setState {selectedItem}


	QuickNoteView = React.createFactory React.createClass
		displayName: 'QuickNoteView'
		mixins: [React.addons.PureRenderMixin]

		render: ->
			R.div({
				className: 'basic progNote'
				## TODO: Restore hover feature
				# onMouseEnter: @props.setHighlightedQuickNoteId.bind null, @props.progNote.get('id')
				# onMouseLeave: @props.setHighlightedQuickNoteId.bind null, null
			},
				R.div({className: 'header'},
					R.div({className: 'timestamp'},
						if @props.progNote.get('backdate') != ''
							Moment(@props.progNote.get('backdate'), Persist.TimestampFormat)
							.format('MMMM D, YYYY') + " (late entry)"
						else
							Moment(@props.progNote.get('timestamp'), Persist.TimestampFormat)
							.format 'MMMM D, YYYY [at] HH:mm'
					)
					R.div({className: 'author'},
						' by '
						@props.progNote.get('author')
					)					
				)
				R.div({
					className: 'notes'
					onClick: @_selectQuickNote
				},
					R.div({className: 'progNoteToolbar'},
						PrintButton({
							dataSet: [
								{
									format: 'progNote'
									data: @props.progNote
									clientFile: @props.clientFile
								}
							]
							isVisible: true
							iconOnly: true
							tooltip: {show: true}
						})
						WithTooltip({title: "Cancel", placement: 'top'},
							OpenDialogLink({
								dialog: CancelProgNoteDialog
								progNote: @props.progNote
								progEvents: @props.progEvents
								disabled: @props.isReadOnly
							},
								R.a({className: 'cancel'},
									FaIcon 'ban'
								)
							)
						)
					)
					renderLineBreaks @props.progNote.get('notes')
				)
			)

		_selectQuickNote: ->
			@props.setSelectedItem Imm.fromJS {
				type: 'quickNote'
				progNoteId: @props.progNote.get('id')
			}

	ProgNoteView = React.createFactory React.createClass
		displayName: 'ProgNoteView'
		mixins: [React.addons.PureRenderMixin]

		_filterEmptyValues: (progNote) ->
			progNoteUnits = progNote.get('units')
			.map (unit) ->
				if unit.get('type') is 'basic'
					# Strip empty metric values
					unitMetrics = unit.get('metrics').filterNot (metric) -> not metric.get('value')
					return unit.set('metrics', unitMetrics)
						
				else if unit.get('type') is 'plan'
					unitSections = unit.get('sections').map (section) ->						
						sectionTargets = section.get('targets')
						# Strip empty metric values
						.map (target) ->
							targetMetrics = target.get('metrics').filterNot (metric) ->
								return not metric.get('value')
							return target.set('metrics', targetMetrics)
						# Strip empty targets
						.filterNot (target) ->
							not target.get('notes') and target.get('metrics').isEmpty()

						return section.set('targets', sectionTargets)

					return unit.set('sections', unitSections)

				else
					throw new Error "Unknown progNote unit type: #{unit.get('type')}"
					
			.filterNot (unit) ->
				# Finally, strip any empty 'basic' notes
				unit.get('type') is 'basic' and not unit.get('notes') and unit.get('metrics').isEmpty()

			return progNote.set('units', progNoteUnits)

		render: ->
			isEditing = @props.isEditing

			# Filter out any empty notes/metrics, unless we're editing
			progNote = if isEditing then @props.revisingProgNote else @_filterEmptyValues(@props.progNote)

			R.div({
				className: 'full progNote'
				## TODO: Restore hover feature
				# onMouseEnter: @props.setHighlightedProgNoteId.bind null, progNote.get('id')
			},
				R.div({className: 'header'},
					R.div({className: 'timestamp'},
						if progNote.get('backdate') != ''
							Moment(progNote.get('backdate'), Persist.TimestampFormat)
							.format('MMMM D, YYYY') + " (late entry)"
						else
							Moment(progNote.get('timestamp'), Persist.TimestampFormat)
							.format 'MMMM D, YYYY [at] HH:mm'
					)
					R.div({className: 'author'},
						' by '
						progNote.get('author')
					)
				)
				R.div({className: 'progNoteList'},
					(unless isEditing
						R.div({className: 'progNoteToolbar'},
							PrintButton({
								dataSet: [
									{
										format: 'progNote'
										data: progNote
										progEvents: @props.progEvents
										clientFile: @props.clientFile
									}
								]
								disabled: isEditing
								isVisible: true
								iconOnly: true
								tooltip: {show: true}
							})
							WithTooltip({title: "Cancel Note", placement: 'top'},
								OpenDialogLink({
									dialog: CancelProgNoteDialog
									progNote: progNote
									progEvents: @props.progEvents
									disabled: @props.isReadOnly
								},
									R.a({className: 'cancel'},
										"Cancel"
									)
								)
							)
							WithTooltip({title: "Edit Note", placement: 'top'},
								R.a({
									className: 'editNote'
									onClick: @props.startRevisingProgNote.bind null, progNote
								},
									"Edit"
								)
							)
						)
					)
					(progNote.get('units').map (unit) =>
						unitId = unit.get 'id'

						switch unit.get('type')
							when 'basic'
								if unit.get('notes')
									R.div({
										className: [
											'basic unit'
											'selected' if @props.selectedItem? and @props.selectedItem.get('unitId') is unitId
										].join ' '
										key: unitId
										onClick: @_selectBasicUnit.bind null, unit
									},
										R.h3({},
											R.input({}, unit.get('name'))
										)
										R.div({className: 'notes'},
											(if isEditing
												ExpandingTextArea({
													value: unit.get('notes')
													onChange: @props.updateBasicUnitNotes.bind null, unitId													
												})
											else
												renderLineBreaks unit.get('notes')
											)
										)
										unless unit.get('metrics').isEmpty()
											R.div({className: 'metrics'},
												(unit.get('metrics').map (metric) =>
													MetricWidget({
														isEditable: false
														key: metric.get('id')
														name: metric.get('name')
														definition: metric.get('definition')
														value: metric.get('value')
													})
												).toJS()...
											)
									)
							when 'plan'
								R.div({
									className: 'plan unit'
									key: unitId
								},
									R.h1({},
										unit.get('name')
									)

									(unit.get('sections').map (section) =>
										sectionId = section.get('id')

										R.section({key: sectionId},
											R.h2({}, section.get('name'))
											R.div({
												## TODO: Restore hover feature
												# onMouseEnter: @props.setHighlightedProgNoteId.bind null, progNote.get('id')
												# onMouseLeave: @props.setHighlightedProgNoteId.bind null, null
												className: [
													'empty'
													showWhen section.get('targets').isEmpty()
												].join ' '
											},
												"This #{Term 'section'} is empty because the #{Term 'client'} has no #{Term 'plan targets'}."
											)
											(section.get('targets').map (target) =>
												targetId = target.get('id')

												R.div({
													key: targetId
													className: [
														'target'
														'selected' if @props.selectedItem? and @props.selectedItem.get('targetId') is targetId
													].join ' '
													onClick: @_selectPlanSectionTarget.bind(null, unit, section, target)
													## TODO: Restore hover feature
													# onMouseEnter: @props.setHighlightedTargetId.bind null, target.get('id')
												},
													R.h3({}, target.get('name'))
													R.div({className: "empty #{showWhen target.get('notes') is '' and not isEditing}"},
														'(blank)'
													)
													R.div({className: 'notes'},
														(if isEditing
															ExpandingTextArea({
																value: target.get('notes')
																onChange: @props.updatePlanTargetNotes.bind null, unitId, sectionId, targetId																
															})
														else
															renderLineBreaks target.get('notes')
														)
													)
													R.div({className: 'metrics'},
														(target.get('metrics').map (metric) =>
															MetricWidget({
																isEditable: isEditing
																# TODO: Modify a metric
																# onChange: @_updatePlanTargetMetric
																key: metric.get('id')
																name: metric.get('name')
																definition: metric.get('definition')
																value: metric.get('value')
															})
														).toJS()...
													)
												)
											).toJS()...
										)
									)
								)
					).toJS()...

					unless @props.progEvents.isEmpty()
						R.div({className: 'progEvents'}
							R.h3({}, Term 'Events')
							(@props.progEvents.map (progEvent) =>								
								ProgEventsWidget({
									key: progEvent.get('id')
									format: 'large'
									data: progEvent
									eventTypes: @props.eventTypes
								})
							).toJS()...
						)						
				)
			)

		_selectBasicUnit: (unit) ->
			@props.setSelectedItem Imm.fromJS {
				type: 'basicUnit'
				unitId: unit.get('id')
				unitName: unit.get('name')
				progNoteId: @props.progNote.get('id')
			}

		_selectPlanSectionTarget: (unit, section, target) ->
			@props.setSelectedItem Imm.fromJS {
				type: 'planSectionTarget'
				unitId: unit.get('id')				
				sectionId: section.get('id')
				targetId: target.get('id')
				targetName: target.get('name')
				progNoteId: @props.progNote.get('id')
			}		



	CancelledProgNoteView = React.createFactory React.createClass
		displayName: 'CancelledProgNoteView'
		getInitialState: ->
			return {
				isExpanded: false
			}

		render: ->
			# Here, we assume that the latest revision was the one that
			# changed the status.  This assumption may become invalid
			# when full prognote editing becomes supported.
			latestRev = @props.progNoteHistory.last()
			statusChangeRev = latestRev

			return R.div({className: 'cancelStub'},
				R.button({
					className: 'toggleDetails btn btn-xs btn-default'
					onClick: @_toggleDetails
				},
					R.span({className: "#{showWhen not @state.isExpanded}"},
						FaIcon 'chevron-down'
						" Show details"
					),
					R.span({className: "#{showWhen @state.isExpanded}"},
						FaIcon 'chevron-up'
						" Hide details"
					),
				)

				R.h3({},
					"Cancelled: ",

					if @props.progNoteHistory.first().get('backdate')
						Moment(@props.progNoteHistory.first().get('backdate'), Persist.TimestampFormat)
						.format('MMMM D, YYYY') + " (late entry)"
					else
						Moment(@props.progNoteHistory.first().get('timestamp'), Persist.TimestampFormat)
						.format 'MMMM D, YYYY, HH:mm'
				),

				R.div({className: "details #{showWhen @state.isExpanded}"},
					R.h4({},
						"Cancelled by ",
						statusChangeRev.get('author')
						" on ",
						Moment(statusChangeRev.get('timestamp'), Persist.TimestampFormat)
						.format 'MMMM D, YYYY [at] HH:mm'
					),
					R.h4({}, "Reason for cancellation:"),
					R.div({className: 'reason'},
						renderLineBreaks latestRev.get('statusReason')
					)

					switch latestRev.get('type')
						when 'basic'
							QuickNoteView({
								progNote: @props.progNoteHistory.first()
								clientFile: @props.clientFile									
								selectedItem: @props.selectedItem
								isReadOnly: true
							})
						when 'full'
							ProgNoteView({
								progNote: @props.progNoteHistory.first()
								progEvents: @props.progEvents
								eventTypes: @props.eventTypes
								clientFile: @props.clientFile
								setSelectedItem: @props.setSelectedItem
								selectedItem: @props.selectedItem
								isReadOnly: true
							})
						else
							throw new Error "unknown prognote type: #{progNote.get('type')}"
				)
			)

		_toggleDetails: (event) ->
			@setState (s) -> {isExpanded: not s.isExpanded}

	return {ProgNotesView}

module.exports = {load}
