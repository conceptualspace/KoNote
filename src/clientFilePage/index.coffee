# Copyright (c) Konode. All rights reserved.
# This source code is subject to the terms of the Mozilla Public License, v. 2.0 
# that can be found in the LICENSE file or at: http://mozilla.org/MPL/2.0

# UI logic for the client file window.
#
# Most of the state for this page is held in a `clientFile` object.  Various
# fields in this object are "transient", meaning that they are not saved when
# the application is closed.  Typically, these track things like what field is
# currently selected.  The function `toSavedFormat` is used to remove these
# transient fields before saving, while `fromSavedFormat` initialize them with
# some default values.

# Libraries from Node.js context
_ = require 'underscore'
Assert = require 'assert'
Async = require 'async'
Imm = require 'immutable'
Moment = require 'moment'

Config = require '../config'
Term = require '../term'
Persist = require '../persist'

load = (win, {clientFileId}) ->
	# Libraries from browser context
	$ = win.jQuery
	Bootbox = win.bootbox
	React = win.React
	R = React.DOM
	Gui = win.require 'nw.gui'
	nwWin = Gui.Window.get(win)
	CrashHandler = require('../crashHandler').load(win)
	Spinner = require('../spinner').load(win)
	BrandWidget = require('../brandWidget').load(win)
	PlanTab = require('./planTab').load(win)
	ProgNotesTab = require('./progNotesTab').load(win)
	AnalysisTab = require('./analysisTab').load(win)
	OpenDialogLink = require('../openDialogLink').load(win)
	RenameClientFileDialog = require('../renameClientFileDialog').load(win)
	{FaIcon, renderName, renderFileId, showWhen, stripMetadata} = require('../utils').load(win)

	ClientFilePage = React.createFactory React.createClass
		getInitialState: ->
			return {
				status: 'init' # Either init or ready
				isLoading: true
				
				clientFile: null
				clientFileLock: null
				readOnlyData: null
				lockOperation: null

				progressNoteHistories: null
				progressEvents: null
				planTargetsById: Imm.Map()
				metricsById: Imm.Map()
				loadErrorType: null
				loadErrorData: null
			}

		init: ->
			@props.maximizeWindow()

			@_renewAllData()

		deinit: (cb=(->)) ->
			@_killLocks cb

		suggestClose: ->
			@refs.ui.suggestClose()

		render: ->
			return ClientFilePageUi({
				ref: 'ui'

				status: @state.status
				isLoading: @state.isLoading
				readOnlyData: @state.readOnlyData
				loadErrorType: @state.loadErrorType

				clientFile: @state.clientFile
				progressNoteHistories: @state.progressNoteHistories
				progressEvents: @state.progressEvents
				planTargetsById: @state.planTargetsById
				metricsById: @state.metricsById
				programs: @state.programs
				eventTypes: @state.eventTypes

				closeWindow: @props.closeWindow
				setWindowTitle: @props.setWindowTitle
				updatePlan: @_updatePlan
				createQuickNote: @_createQuickNote
			})

		_renewAllData: ->
			console.log "Renewing all data......"

			# Sync check
			fileIsUnsync = null
			# File data
			clientFile = null
			planTargetsById = null
			planTargetHeaders = null
			progNoteHeaders = null
			progressNoteHistories = null
			progEventHeaders = null
			progressEvents = null
			metricHeaders = null
			metricsById = null
			clientFileProgramLinkHeaders = null
			programHeaders = null
			programs = null
			eventTypes = null
			eventTypeHeaders = null

			checkFileSync = (newData, oldData) => 
				unless fileIsUnsync
					fileIsUnsync = not Imm.is oldData, newData

			# Begin the clientFile data load process
			@setState (state) => {isLoading: true}
			Async.series [
				(cb) => 
					unless @state.clientFileLock?
						@_acquireLock cb
					else
						cb()

				(cb) =>
					ActiveSession.persist.clientFiles.readLatestRevisions clientFileId, 1, (err, revisions) =>
						if err
							cb err
							return

						clientFile = stripMetadata revisions.get(0)

						checkFileSync clientFile, @state.clientFile
						cb()

				(cb) =>
					ActiveSession.persist.planTargets.list clientFileId, (err, results) =>
						if err
							cb err
							return

						planTargetHeaders = results
						cb()

				(cb) =>
					Async.map planTargetHeaders.toArray(), (planTargetHeader, cb) =>
						targetId = planTargetHeader.get('id')
						ActiveSession.persist.planTargets.readRevisions clientFileId, targetId, cb
					, (err, results) =>
						if err
							cb err
							return

						planTargetsById = Imm.List(results).map (planTargetRevs) =>
							id = planTargetRevs.getIn([0, 'id'])
							return [
								id
								Imm.Map({id, revisions: planTargetRevs.reverse()})
							]
						.fromEntrySeq().toMap()

						checkFileSync planTargetsById, @state.planTargetsById
						cb()

				(cb) =>
					ActiveSession.persist.progNotes.list clientFileId, (err, results) =>
						if err
							cb err
							return

						progNoteHeaders = results
						cb()

				(cb) =>
					Async.map progNoteHeaders.toArray(), (progNoteHeader, cb) =>
						ActiveSession.persist.progNotes.readRevisions clientFileId, progNoteHeader.get('id'), cb
					, (err, results) =>
						if err
							cb err
							return

						progressNoteHistories = Imm.List(results)

						checkFileSync progressNoteHistories, @state.progressNoteHistories
						cb()

				(cb) =>
					ActiveSession.persist.progEvents.list clientFileId, (err, results) =>
						if err
							cb err
							return

						progEventHeaders = results
						cb()

				(cb) =>
					Async.map progEventHeaders.toArray(), (progEventHeader, cb) =>
						ActiveSession.persist.progEvents.read clientFileId, progEventHeader.get('id'), cb
					, (err, results) =>
						if err
							cb err
							return

						progressEvents = Imm.List results

						checkFileSync progressEvents, @state.progressEvents
						cb()

				(cb) =>
					ActiveSession.persist.metrics.list (err, results) =>
						if err
							cb err
							return

						metricHeaders = results
						cb()

				(cb) =>
					Async.map metricHeaders.toArray(), (metricHeader, cb) =>
						ActiveSession.persist.metrics.read metricHeader.get('id'), cb
					, (err, results) =>
						if err
							cb err
							return

						metricsById = Imm.List(results)
						.map (metric) =>
							return [metric.get('id'), metric]
						.fromEntrySeq().toMap()

						checkFileSync metricsById, @state.metricsById
						cb()				

				(cb) =>
					ActiveSession.persist.clientFileProgramLinks.list (err, results) =>
						if err
							cb err
							return

						clientFileProgramLinkHeaders = results
						.filter (link) ->
							link.get('clientFileId') is clientFileId and
							link.get('status') is "enrolled"
						.map (link) ->
							link.get('programId')

						cb()

				(cb) =>
					ActiveSession.persist.programs.list (err, results) =>
						if err
							cb err
							return

						programHeaders = results
						.filter (program) -> 
							thisProgramId = program.get('id')
							clientFileProgramLinkHeaders.contains thisProgramId

						cb()
				(cb) =>
					Async.map programHeaders.toArray(), (programHeader, cb) =>
						console.log programHeader.get('id')
						ActiveSession.persist.programs.readLatestRevisions programHeader.get('id'), 1, cb
					, (err, results) =>
						if err
							cb err
							return

						programs = Imm.List(results)
						.map (program) -> stripMetadata program.get(0)

						checkFileSync programs, @state.programs
						cb()
				(cb) =>
					ActiveSession.persist.eventTypes.list (err, result) =>
						if err
							cb err
							return

						eventTypeHeaders = result
						cb()
				(cb) =>
					Async.map eventTypeHeaders.toArray(), (eventTypeheader, cb) =>
						eventTypeId = eventTypeheader.get('id')

						ActiveSession.persist.eventTypes.readLatestRevisions eventTypeId, 1, cb
					, (err, results) =>
						if err
							cb err
							return

						eventTypes = Imm.List(results).map (eventType) -> stripMetadata eventType.get(0)
						cb()
			], (err) =>
				if err
					if err instanceof Persist.IOError
						console.error err
						console.error err.stack
						@setState {loadErrorType: 'io-error'}
						return

					CrashHandler.handle err
					return

				# Trigger readOnly mode when hasChanges and unsynced
				if @state.clientFile? and @refs.ui.hasChanges() and fileIsUnsync
					console.log "Handling remote changes vs local changes..."

					@setState {
						isLoading: false
						readOnlyData: {
							message: "Please back up your changes, and click here to reload the file"
							clickAction: => @props.refreshWindow()
						}
					}, =>
						clientName = renderName @state.clientFile.get('clientName')
						Bootbox.dialog {
							title: "Refresh #{Term 'Client File'}?"
							message: "This #{Term 'client file'} for #{clientName} has been
							revised since your session timed out. This #{Term 'file'}
							must be refreshed, and your unsaved changes will be lost! 
							What would you like to do?"
							buttons: {
								cancel: {
									label: "I'll back up my changes first"
									className: 'btn-success'
								}
								success: {
									label: "Reload #{Term 'client file'} now"
									className: 'btn-warning'
									callback: => @props.refreshWindow()
								}
							}
						}
				else
					# OK, load in clientFile state data!
					console.log "Injected load data into @state"
					console.info "programs", programs.toJS()
					@setState {
						clientFile						
						progressNoteHistories
						progressEvents
						metricsById
						planTargetsById
						programs
						eventTypes

						isLoading: false
						status: 'ready'
					}

		_acquireLock: (cb=(->)) ->
			lockFormat = "clientFile-#{clientFileId}"

			Persist.Lock.acquire global.ActiveSession, lockFormat, (err, lock) =>
				if err
					if err instanceof Persist.Lock.LockInUseError

						pingInterval = Config.clientFilePing.acquireLock

						# Prepare readOnly message
						lockOwner = err.metadata.userName
						readOnlyMessage = if lockOwner is global.ActiveSession.userName
							"You already have this file open in another window"
						else
							"File currently in use by username: \"#{lockOwner}\""

						@setState {
							readOnlyData: {message: readOnlyMessage}

							# Keep checking for lock availability, returns new lock when true
							lockOperation: Persist.Lock.acquireWhenFree global.ActiveSession, lockFormat, pingInterval, (err, newLock) =>
								if err
									cb err
									return

								if newLock
									# Alert user about lock acquisition
									clientName = renderName @state.clientFile.get('clientName')
									new win.Notification "#{clientName} file unlocked", {
										body: "You now have the read/write permissions for this #{Term 'client file'}"
									}
									@setState {
										clientFileLock: newLock
										readOnlyData: null
									}, @_renewAllData
								else
									console.log "acquireWhenFree operation cancelled"							
						}, cb
					else
						cb err

				else
					@setState {
						clientFileLock: lock
						readOnlyData: null
						lockOperation: null
					}, cb

		_killLocks: (cb=(->)) ->
			console.log "Killing locks...."
			if @state.clientFileLock?
				@state.clientFileLock.release(=>
					@setState {clientFileLock: null}, =>
						console.log "Lock killed!"
						cb()
				)
			else if @state.lockOperation?
				@state.lockOperation.cancel cb

		_updatePlan: (plan, newPlanTargets, updatedPlanTargets) ->
			@setState (state) => {isLoading: true}

			idMap = Imm.Map()

			Async.series [
				(cb) =>
					Async.each newPlanTargets.toArray(), (newPlanTarget, cb) =>
						transientId = newPlanTarget.get('id')
						newPlanTarget = newPlanTarget.delete('id')

						ActiveSession.persist.planTargets.create newPlanTarget, (err, result) =>
							if err
								cb err
								return

							persistentId = result.get('id')
							idMap = idMap.set(transientId, persistentId)
							cb()
					, cb
				(cb) =>
					Async.each updatedPlanTargets.toArray(), (updatedPlanTarget, cb) =>
						ActiveSession.persist.planTargets.createRevision updatedPlanTarget, cb
					, cb
				(cb) =>
					# Replace transient IDs with newly created persistent IDs
					newPlan = plan.update 'sections', (sections) =>
						return sections.map (section) =>
							return section.update 'targetIds', (targetIds) =>
								return targetIds.map (targetId) =>
									return idMap.get(targetId, targetId)
					newClientFile = @state.clientFile.set 'plan', newPlan

					# If no changes, skip this step
					if Imm.is(newClientFile, @state.clientFile)
						cb()
						return

					ActiveSession.persist.clientFiles.createRevision newClientFile, cb
				(cb) =>
					# Add a noticeable delay so that the user knows the save happened.
					setTimeout cb, 400
			], (err) =>
				@setState (state) => {isLoading: false}

				if err
					if err instanceof Persist.IOError
						Bootbox.alert """
							An error occurred.  Please check your network connection and try again.
						"""
						return

					CrashHandler.handle err
					return

				# Nothing else to do.
				# Persist operations will automatically trigger event listeners
				# that update the UI.

		_createQuickNote: (notes, backdate, cb) ->
			if notes != ''
				note = Imm.fromJS {
					type: 'basic'
					status: 'default'
					clientFileId
					notes
					backdate
				}

				@setState (state) => {isLoading: true}
				global.ActiveSession.persist.progNotes.create note, (err) =>
					@setState (state) => {isLoading: false}

					if err
						cb err
						return

					cb()

		getPageListeners: ->
			return {
				'createRevision:clientFile': (newRev) =>
					return unless newRev.get('id') is clientFileId
					@setState {clientFile: newRev}

				'create:planTarget createRevision:planTarget': (newRev) =>
					return unless newRev.get('clientFileId') is clientFileId
					@setState (state) =>
						targetId = newRev.get('id')
						if state.planTargetsById.has targetId
							planTargetsById = state.planTargetsById.updateIn [targetId, 'revisions'], (revs) =>
								return revs.unshift newRev
						else
							planTargetsById = state.planTargetsById.set targetId, Imm.fromJS {
								id: targetId
								revisions: [newRev]
							}
						return {planTargetsById}

				'create:progNote': (newProgNote) =>
					return unless newProgNote.get('clientFileId') is clientFileId

					@setState (state) =>
						return {
							progressNoteHistories: state.progressNoteHistories.push Imm.List([newProgNote])
						}

				'createRevision:progNote': (newProgNoteRev) =>
					return unless newProgNoteRev.get('clientFileId') is clientFileId

					@setState (state) =>
						return {
							progressNoteHistories: state.progressNoteHistories.map (progNoteHist) =>
								if progNoteHist.first().get('id') is newProgNoteRev.get('id')
									return progNoteHist.push newProgNoteRev

								return progNoteHist
						}

				'create:progEvent': (newProgEvent) =>
					return unless newProgEvent.get('clientFileId') is clientFileId
					@setState (state) => progressEvents: state.progressEvents.push newProgEvent

				'create:metric': (newMetric) =>
					@setState (state) => metricsById: state.metricsById.set newMetric.get('id'), newMetric

				'create:eventType': (newEventType) =>
					@setState (state) => eventTypes: state.eventTypes.push newEventType

				'createRevision:eventType': (newEventTypeRev) =>
					originalEventType = @state.eventTypes
					.find (eventType) -> eventType.get('id') is newEventTypeRev.get('id')
					
					eventTypeIndex = @state.eventTypes.indexOf originalEventType

					@setState {eventTypes: @state.eventTypes.set(eventTypeIndex, newEventTypeRev)}

				'timeout:timedOut': =>
					@_killLocks Bootbox.hideAll

				'timeout:reactivateWindows': =>
					@_renewAllData()
			}

	ClientFilePageUi = React.createFactory React.createClass
		mixins: [React.addons.PureRenderMixin]

		getInitialState: ->
			return {
				activeTabId: 'plan'
			}

		hasChanges: ->
			# Eventually this will cover more
			# components where unsaved changes can occur
			if @refs.planTab?
				@refs.planTab.hasChanges()
			else
				false

		suggestClose: ->
			# If page still loading
			# TODO handle this more elegantly
			unless @props.clientFile?
				@props.closeWindow()
				return

			clientName = renderName @props.clientFile.get('clientName')

			if @refs.planTab.hasChanges()
				Bootbox.dialog {
					title: "Unsaved Changes to #{Term 'Plan'}"
					message: """
						You have unsaved changes in this #{Term 'plan'} for #{clientName}. 
						How would you like to proceed?
					"""
					buttons: {
						default: {
							label: "Cancel"
							className: "btn-default"
							callback: => Bootbox.hideAll()
						}
						danger: {
							label: "Discard Changes"
							className: "btn-danger"
							callback: => 
								@props.closeWindow()
						}
						success: {
							label: "View #{Term 'Plan'}"
							className: "btn-success"
							callback: => 
								Bootbox.hideAll()
								@setState {activeTabId: 'plan'}, @refs.planTab.blinkUnsaved
						}
					}
				}
			else
				@props.closeWindow()

		render: ->
			if @props.loadErrorType
				return LoadError {
					loadErrorType: @props.loadErrorType
					closeWindow: @props.closeWindow
				}

			if @props.status is 'init'
				return R.div({className: 'clientFilePage'},
					Spinner {
						isOverlay: true
						isVisible: true
					}
				)

			Assert @props.status is 'ready'

			activeTabId = @state.activeTabId
			isReadOnly = @props.readOnlyData?

			clientName = renderName @props.clientFile.get('clientName')
			recordId = @props.clientFile.get('recordId')
			@props.setWindowTitle """
				#{Config.productName} (#{global.ActiveSession.userName}) - 
				#{clientName}: #{Term 'Client File'}
			"""

			# Sort progNotes by timestamp unixMs (backdate if exists)
			sortedProgNoteHistories = @props.progressNoteHistories
			.sortBy (progNoteHist) ->
				createdAt = progNoteHist.last().get('backdate') or progNoteHist.first().get('timestamp')
				return Moment createdAt, Persist.TimestampFormat
			.reverse()

			return R.div({className: 'clientFilePage animated fadeIn'},
				Spinner({isOverlay: true, isVisible: @props.isLoading})

				(if isReadOnly
					ReadOnlyNotice {data: @props.readOnlyData}
				)
				R.div({className: 'wrapper'},
					Sidebar({
						clientFile: @props.clientFile
						clientName
						recordId
						activeTabId
						onTabChange: @_changeTab
						programs: @props.programs
					})
					PlanTab.PlanView({
						ref: 'planTab'
						isVisible: activeTabId is 'plan'
						clientFileId
						clientFile: @props.clientFile
						plan: @props.clientFile.get('plan')
						planTargetsById: @props.planTargetsById
						metricsById: @props.metricsById
						updatePlan: @props.updatePlan
						isReadOnly
					})
					ProgNotesTab.ProgNotesView({
						isVisible: activeTabId is 'progressNotes'
						clientFileId
						clientFile: @props.clientFile
						progNoteHistories: sortedProgNoteHistories
						progEvents: @props.progressEvents
						eventTypes: @props.eventTypes
						metricsById: @props.metricsById
						
						hasChanges: @hasChanges
						onTabChange: @_changeTab

						createQuickNote: @props.createQuickNote
						isReadOnly
					})
					AnalysisTab.AnalysisView({
						isVisible: activeTabId is 'analysis'
						clientFileId
						progNoteHistories: sortedProgNoteHistories
						progEvents: @props.progressEvents
						eventTypes: @props.eventTypes
						metricsById: @props.metricsById
						isReadOnly
					})
				)
			)
		_changeTab: (newTabId) ->
			@setState {
				activeTabId: newTabId
			}

	Sidebar = React.createFactory React.createClass
		mixins: [React.addons.PureRenderMixin]
		render: ->
			activeTabId = @props.activeTabId

			return R.div({className: 'sidebar'},
				R.img({src: Config.customerLogoLg}),
				R.div({className: 'logoSubtitle'},
					Config.logoSubtitle
				)
				R.div({className: 'clientName'},
					(if ActiveSession.accountType is 'admin'
						OpenDialogLink({
							dialog: RenameClientFileDialog
							clientFile: @props.clientFile
						},
							@props.clientName
						)
					else
						@props.clientName
					)
				)
				R.div({className: 'programs'},
					@props.programs.map (program) ->
						R.span({
							key: program.get('id')
							style:
								borderBottomColor: program.get('colorKeyHex')
						},
							program.get('name')
						)
				)
				R.div({className: 'programs'},
					@props.programs.map (program) ->
						R.span({
							key: program.get('id')
							style:
								borderBottomColor: program.get('colorKeyHex')
						},
							program.get('name')
						)
				)
				R.div({className: 'recordId'},
					R.span({}, renderFileId @props.recordId, true)
				)
				R.div({className: 'tabStrip'},
					SidebarTab({
						name: Term('Plan')
						icon: 'sitemap'
						isActive: activeTabId is 'plan'
						onClick: @props.onTabChange.bind null, 'plan'
					})
					SidebarTab({
						name: Term('Progress Notes')
						icon: 'pencil-square-o'
						isActive: activeTabId is 'progressNotes'
						onClick: @props.onTabChange.bind null, 'progressNotes'
					})
					SidebarTab({
						name: Term('Analysis')
						icon: 'line-chart'
						isActive: activeTabId is 'analysis'
						onClick: @props.onTabChange.bind null, 'analysis'
					})
				)				
				BrandWidget()
			)

	SidebarTab = React.createFactory React.createClass
		mixins: [React.addons.PureRenderMixin]
		render: ->
			return R.div({
				className: "tab #{if @props.isActive then 'active' else ''}"
				onClick: @props.onClick
			},
				FaIcon @props.icon
				' '
				@props.name
			)

	LoadError = React.createFactory React.createClass
		mixins: [React.addons.PureRenderMixin]
		componentDidMount: ->
			console.log "loadErrorType:", @props.loadErrorType
			msg = switch @props.loadErrorType
				when 'io-error'
					"""
						An error occurred while loading the #{Term 'client file'}. 
						This may be due to a problem with your network connection.
					"""
				else
					"An unknown error occured (loadErrorType: #{@props.loadErrorType}"				
			Bootbox.alert msg, =>
				@props.closeWindow()
		render: ->
			return R.div({className: 'clientFilePage'})

	ReadOnlyNotice = React.createFactory React.createClass
		mixins: [React.addons.PureRenderMixin]
		render: ->
			return R.div({
				className: 'readOnlyNotice'
			},				
				R.div({
					className: [
						"notice"
						"clickable" if @props.data.clickAction?
					].join ' '
					onClick: @props.data.clickAction
				},
					@props.data.message
				)
				R.div({className: 'mode'}, 
					@props.data.mode or "Read-Only Mode"
				)
			)

	return ClientFilePage

module.exports = {load}