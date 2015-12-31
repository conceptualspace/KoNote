# Copyright (c) Konode. All rights reserved.
# This source code is subject to the terms of the Mozilla Public License, v. 2.0 
# that can be found in the LICENSE file or at: http://mozilla.org/MPL/2.0

# Libraries from Node.js context
Imm = require 'immutable'
Async = require 'async'
_ = require 'underscore'

Config = require './config'
Term = require './term'
Persist = require './persist'

load = (win) ->
	# Libraries from browser context
	$ = win.jQuery
	Bootbox = win.bootbox
	React = win.React
	R = React.DOM
	Gui = win.require 'nw.gui'
	Window = Gui.Window.get()

	ManagerLayer = require('./managerLayer').load(win)		
	Spinner = require('./spinner').load(win)
	BrandWidget = require('./brandWidget').load(win)	
	OrderableTable = require('./orderableTable').load(win)
	OpenDialogLink = require('./openDialogLink').load(win)

	CreateClientFileDialog = require('./createClientFileDialog').load(win)

	CrashHandler = require('./crashHandler').load(win)
	{FaIcon, openWindow, renderName, showWhen, stripMetadata} = require('./utils').load(win)

	ClientSelectionPage = React.createFactory React.createClass
		getInitialState: ->
			return {
				isLoading: true
				clientFileHeaders: Imm.List()
				programs: Imm.List()
				clientFileProgramLinks: Imm.List()
			}

		init: ->
			@props.setWindowTitle """
				#{Config.productName} (#{global.ActiveSession.userName})
			"""
			@_loadData()

		deinit: (cb=(->)) ->
			# Nothing need be done
			cb()

		suggestClose: ->
			@props.closeWindow()			

		render: ->
			return ClientSelectionPageUi({
				isLoading: @state.isLoading
				clientFileHeaders: @state.clientFileHeaders
				clientFileProgramLinks: @state.clientFileProgramLinks
				programs: @state.programs
			})

		_loadData: ->
			clientFileHeaders = null
			programHeaders = null
			programs = null
			clientFileProgramLinkHeaders = null
			clientFileProgramLinks = null

			Async.series [
				(cb) =>
					ActiveSession.persist.clientFiles.list (err, result) =>
						if err
							cb err
							return

						clientFileHeaders = result
						cb()
				(cb) =>
					ActiveSession.persist.programs.list (err, result) =>
						if err
							cb err
							return

						programHeaders = result
						cb()
				(cb) =>
					Async.map programHeaders.toArray(), (programHeader, cb) =>
						progId = programHeader.get('id')

						ActiveSession.persist.programs.readLatestRevisions progId, 1, cb
					, (err, results) =>
						if err
							cb err
							return

						programs = Imm.List(results).map (program) -> stripMetadata program.get(0)
						cb()
				(cb) =>
					ActiveSession.persist.clientFileProgramLinks.list (err, result) =>
						if err
							cb err
							return
						clientFileProgramLinkHeaders = result
						cb()
				(cb) =>
					Async.map clientFileProgramLinkHeaders.toArray(), (linkHeader, cb) =>
						linkId = linkHeader.get('id')

						ActiveSession.persist.clientFileProgramLinks.readLatestRevisions linkId, 1, cb
					, (err, results) =>
						if err
							cb err
							return

						clientFileProgramLinks = Imm.List(results).map (link) -> stripMetadata link.get(0)
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

				# Data loaded successfully, load into state
				@setState {
					isLoading: false
					programs
					clientFileHeaders
					clientFileProgramLinks
				}

		getPageListeners: ->
			return {

				'create:clientFile': (newFile) =>
					clientFileHeaders = @state.clientFileHeaders.push newFile
					@setState {clientFileHeaders}, =>
						openWindow {
							page: 'clientFile'
							clientFileId: newFile.get('id')
						}

				# TODO: Create a function for this kind of listening/updating

				'create:program createRevision:program': (newRev) =>
					programId = newRev.get('id')
					# Updating or creating program?
					existingProgram = @state.programs
					.find (program) -> program.get('id') is programId

					@setState (state) ->
						if existingProgram?
							programIndex = state.programs.indexOf existingProgram
							programs = state.programs.set programIndex, newRev
						else
							programs = state.programs.push newRev

						return {programs}

				'create:clientFileProgramLink createRevision:clientFileProgramLink': (newRev) =>
					linkId = newRev.get('id')
					# Updating or creating link?
					existingLink = @state.clientFileProgramLinks
					.find (link) -> link.get('id') is linkId

					@setState (state) ->
						if existingLink?
							linkIndex = state.clientFileProgramLinks.indexOf existingLink
							clientFileProgramLinks = state.clientFileProgramLinks.set linkIndex, newRev
						else
							clientFileProgramLinks = state.clientFileProgramLinks.push newRev

						return {clientFileProgramLinks}					

			}

	ClientSelectionPageUi = React.createFactory React.createClass
		mixins: [React.addons.PureRenderMixin]

		getInitialState: ->
			return {
				isSmallHeaderSet: false
				menuIsOpen: false

				queryText: ''
				queryResults: Imm.List()				
				hoverClientId: null

				managerLayer: null
			}

		componentDidUpdate: (oldProps, oldState) ->
			# If loading just finished
			if oldProps.isLoading and not @props.isLoading

				setTimeout(=>
					$searchBox = $(@refs.searchBox)
					$searchBox.focus()
					@_attachKeyBindings($searchBox)
				, 500)

			if @props.clientFileHeaders isnt oldProps.clientFileHeaders
				@_refreshResults()

			if @state.queryText isnt oldState.queryText
				@_refreshResults()

		componentDidMount: ->
			@_refreshResults()

		render: ->
			isAdmin = global.ActiveSession.isAdmin()
			smallHeader = @state.queryText.length > 0 or @state.isSmallHeaderSet	

			# Add in all program objects this clientFile's a member of
			queryResults = @state.queryResults.map (clientFile) =>
				clientFileId = clientFile.get('id')

				programMemberships = @props.clientFileProgramLinks
				.filter (link) =>
					link.get('clientFileId') is clientFileId and link.get('status') is "enrolled"
				.map (link) =>
					@props.programs.find (program) -> program.get('id') is link.get('programId')

				clientFile.set('programs', programMemberships)

			return R.div({
					id: 'clientSelectionPage'
					className: [
						'animated fadeIn'
						if @state.menuIsOpen then 'openMenu' else ''
					].join ' '
			},
				if @props.isLoading
					R.div({id: 'clientSelectionPage'},
						Spinner {
							isOverlay: true
							isVisible: true
						}
					)
				R.a({
					id: 'expandMenuButton'					
					onClick: =>
						@_toggleUserMenu()
						@refs.searchBox.focus() if @state.menuIsOpen

				},					
					FaIcon(if @state.managerLayer? then 'times' else 'bars')
				)
				R.div({
					id: 'mainContainer'					
				},
					(if @state.managerLayer?
						ManagerLayer({
							# Settings
							name: @state.managerLayer
							# Data
							clientFileHeaders: @props.clientFileHeaders							
							programs: @props.programs
							clientFileProgramLinks: @props.clientFileProgramLinks							
						})
					)
					R.div({
						id: 'main'
						onClick: =>
							@_toggleUserMenu() if @state.menuIsOpen
							@refs.searchBox.focus()
					},
						Spinner({
							isVisible: @props.isLoading
							isOverlay: true
						})						
						R.header({
							className: [
								if smallHeader then 'small' else ''
								showWhen not @props.isLoading
							].join ' '
						},								
							R.div({className: 'logoContainer'},
								R.img({src: Config.customerLogoLg})
								R.div({
									className: 'subtitle'
									style: {color: Config.logoSubtitleColor}
								},
									Config.logoSubtitle
								)
							)
							R.div({className: 'searchBoxContainer input-group'},
								R.input({
									className: 'searchBox form-control'
									ref: 'searchBox'
									type: 'text'
									onChange: @_updateQueryText
									placeholder: "Search for a #{Term 'client'}'s profile..."
									value: @state.queryText
								})
								R.span({
									className: 'input-group-btn'
								},
									R.button({
										className: "btn btn-default"
										onClick: @_showAll
									},
										'Show All'
									)
								)
							)
						)
						R.div({
							className: [
								'smallHeaderLogo'
								if smallHeader then 'show' else 'hidden'
								showWhen not @props.isLoading
							].join ' '
						},
							R.img({
								src: Config.customerLogoLg
								onClick: @_home
							})
						)
						R.div({
							className: [
								'results'
								if smallHeader then 'show' else 'hidden'
								showWhen not @props.isLoading
							].join ' '
						},
							OrderableTable({
								tableData: queryResults
								sortByData: ['clientName', 'last']
								key: ['id']
								rowClass: (dataPoint) =>
									'active' if @state.hoverClientId is dataPoint.get('id')
								onClickRow: (dataPoint) =>
									@_onResultSelection.bind null, dataPoint.get('id')

								columns: [
									{
										name: Term 'Programs'
										dataPath: ['programs']
										cellClass: 'programsCell'
										isNotOrderable: true
										nameIsVisible: false

										value: (dataPoint) ->
											programs = dataPoint.get('programs')

											return R.div({className: 'programBubbles'}, 
												(programs
													.sortBy (program) -> program.get('name').toLowerCase()
													.map (program) -> 
														ProgramBubble({
															program
															key: program.get('id')
														})
												)
											)
									}
									{
										name: "Last Name"
										dataPath: ['clientName', 'last']
									}
									{
										name: "Given Name(s)"
										dataPath: ['clientName', 'first']
										extraPath: ['clientName', 'middle']
									}
									{
										name: Config.clientFileRecordId.label
										dataPath: ['recordId']
										isDisabled: not Config.clientFileRecordId.isEnabled
									}
								]
							})
						)
					)
				)

				(if @state.menuIsOpen
					R.aside({
						id: 'menuContainer'
						ref: 'userMenu'
						className: 'menuIsOpen animated fadeInRight'
					},
						R.div({id: 'menuContent'},
							R.div({id: 'avatar'}, FaIcon('user'))
							R.h3({}, global.ActiveSession.userName)
							R.ul({},
								UserMenuItem({									
									title: "New #{Term 'Client File'}"
									icon: 'folder-open'
									dialog: CreateClientFileDialog
									onClick: @_updateManagerLayer.bind null, null
								})
								UserMenuItem({
									isVisible: isAdmin
									title: Term 'Programs'
									icon: 'users'
									onClick: @_updateManagerLayer.bind null, 'programManagerTab'
									isActive: @state.managerLayer is 'programManagerTab'
								})								
								UserMenuItem({
									isVisible: isAdmin
									title: "Event Types"
									icon: 'calendar-o'
									onClick: @_updateManagerLayer.bind null, 'eventTypeManagerTab'
									isActive: @state.managerLayer is 'eventTypeManagerTab'
								})
								UserMenuItem({
									isVisible: isAdmin
									title: "User #{Term 'Accounts'}"
									icon: 'key'
									onClick: @_updateManagerLayer.bind null, 'accountManagerTab'
									isActive: @state.managerLayer is 'accountManagerTab'
								})								
								UserMenuItem({
									isVisible: isAdmin
									title: "Export Data"
									icon: 'upload'
									onClick: @_updateManagerLayer.bind null, 'exportManagerTab'
									isActive: @state.managerLayer is 'exportManagerTab'
								})
								UserMenuItem({
									title: "My #{Term 'Account'}"
									icon: 'cog'
									onClick: @_updateManagerLayer.bind null, 'myAccountManagerTab'
									isActive: @state.managerLayer is 'myAccountManagerTab'
								})
							)
						)
					)
				)
			)

		_attachKeyBindings: ($searchBox) ->
			# Key-bindings for searchBox
			$searchBox.on 'keydown', (event) =>
				# Don't need to see this unless in full search view
				return if not @state.isSmallHeaderSet

				switch event.which
					when 40 # Down arrow
						event.preventDefault()
						@_shiftHoverClientId(1)
					when 38 # Up arrow
						event.preventDefault()
						@_shiftHoverClientId(-1)
					when 27 # Esc
						@setState hoverClientId: null
					when 13 # Enter
						$active = $('.active')
						return unless $active.length
						$active[0].click()
						return false

		_shiftHoverClientId: (modifier) ->
			hoverClientId = null
			queryResults = @state.queryResults

			# Get our current index position
			currentResultIndex = queryResults.findIndex (result) =>
				return result.get('id') is @state.hoverClientId

			nextIndex = currentResultIndex + modifier

			# Skip to first/last if first-run or next is non-existent
			if not queryResults.get(nextIndex)? or not @state.hoverClientId?
				if modifier > 0
					hoverClientId = queryResults.first().get('id')
				else
					hoverClientId = queryResults.last().get('id')

				@setState {hoverClientId}
				return

			# No wacky skip behaviour needed, move to next/previous result
			hoverClientId = queryResults.get(nextIndex).get('id')
			@setState {hoverClientId}

		_updateManagerLayer: (managerLayer) ->
			@setState {managerLayer}

		_toggleUserMenu: ->
			if @state.menuIsOpen
				$(@refs.userMenu).addClass('slideOutRight')

				@setState {managerLayer: null}

				setTimeout(=>
					@setState {
						menuIsOpen: false						
					}
				, 400)
			else
				@setState {menuIsOpen: true}

		_refreshResults: ->
			# Return all results if search query is empty
			if @state.queryText.trim().length is 0
				@setState {queryResults: @props.clientFileHeaders}
				return

			# Split into query parts
			queryParts = Imm.fromJS(@state.queryText.split(' '))
			.map (p) -> p.toLowerCase()

			# Calculate query results
			queryResults = @props.clientFileHeaders
			.filter (clientFile) ->
				firstName = clientFile.getIn(['clientName', 'first']).toLowerCase()
				middleName = clientFile.getIn(['clientName', 'middle']).toLowerCase()
				lastName = clientFile.getIn(['clientName', 'last']).toLowerCase()
				recordId = clientFile.getIn(['recordId']).toLowerCase()

				return queryParts
				.every (part) ->
					return firstName.includes(part) or
						middleName.includes(part) or
						lastName.includes(part) or
						recordId.includes(part)			

			@setState {queryResults}

		_updateQueryText: (event) ->
			@setState {queryText: event.target.value}

			if event.target.value.length > 0
				@setState {isSmallHeaderSet: true}

		_showAll: ->
			@setState {isSmallHeaderSet: true, queryText: ''}
		_home: ->
			@setState {isSmallHeaderSet: false, queryText: ''}
		_onResultSelection: (clientFileId, event) ->
			openWindow {
				page: 'clientFile'
				clientFileId
			}	


	UserMenuItem = React.createFactory React.createClass
		mixins: [React.addons.PureRenderMixin]

		getDefaultProps: ->
			return {
				isVisible: true
				isActive: false
				onClick: ->
				dialog: null
			}

		render: ->
			return R.li({
				className: [
					'active' if @props.isActive
					showWhen @props.isVisible
				].join ' '
				onClick: @props.onClick
			},
				if @props.dialog?
					OpenDialogLink({dialog: @props.dialog},
						FaIcon(@props.icon)
						@props.title
					)
				else
					R.div({},
						FaIcon(@props.icon)
						@props.title
					)
			)

	ProgramBubble = React.createFactory React.createClass
		mixins: [React.addons.PureRenderMixin]

		componentDidMount: ->
			$(@refs.bubble).popover {
				trigger: 'hover'
				placement: 'right'
				title: @props.program.get('name')
				content: @props.program.get('description')
			}
		render: ->
			return R.div({
				className: 'programBubble'
				ref: 'bubble'				
				style:
					background: @props.program.get('colorKeyHex')
			})


	return ClientSelectionPage

module.exports = {load}