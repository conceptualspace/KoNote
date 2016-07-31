# Copyright (c) Konode. All rights reserved.
# This source code is subject to the terms of the Mozilla Public License, v. 2.0
# that can be found in the LICENSE file or at: http://mozilla.org/MPL/2.0

Async = require 'async'
Imm = require 'immutable'
Assert = require 'assert'

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

	NewInstallationPage = require('./newInstallationPage').load(win)

	CrashHandler = require('./crashHandler').load(win)
	Spinner = require('./spinner').load(win)
	Dialog = require('./dialog').load(win)
	{FaIcon, openWindow, renderName, showWhen} = require('./utils').load(win)

	LoginPage = React.createFactory React.createClass
		displayName: 'LoginPage'
		mixins: [React.addons.PureRenderMixin]

		getInitialState: ->
			return {
				isSetUp: null
				isNewSetUp: null

				isLoading: false
			}

		init: ->
			@_checkSetUp()

		deinit: (cb=(->)) ->
			@setState {isLoading: false}, cb

		suggestClose: ->
			@props.closeWindow()

		_activateWindow: ->
			@setState {isSetUp: true}
			Window.show()
			Window.focus()

		render: ->
			unless @state.isSetUp
				return R.div({})

			LoginPageUi({
				ref: 'ui'

				isLoading: @state.isLoading
				loadingMessage: @state.loadingMessage

				isSetUp: @state.isSetUp
				isNewSetUp: @state.isNewSetUp
				activateWindow: @_activateWindow
				login: @_login
			})

		_checkSetUp: ->
			console.log "Probing setup..."

			# Check to make sure the dataDir exists and has an account system
			Persist.Users.isAccountSystemSetUp Config.dataDirectory, (err, isSetUp) =>
				@setState {isLoading: false}

				if err
					CrashHandler.handle err
					return

				if isSetUp
					# Already set up, no need to continue here
					console.log "Set up confirmed..."
					@setState {isSetUp: true}
					return

				# Falsy isSetUp triggers NewInstallationPage
				console.log "Not set up, redirecting to installation page..."
				@setState {isSetUp: false}

				openWindow {page: 'newInstallation'}, (newInstallationWindow) =>
					# Hide loginPage while installing
					Window.hide()

					newInstallationWindow.on 'closed', (event) =>
						if global.isSetUp
							# Successfully installed, show login with isNewSetUp
							@setState {
								isSetUp: true
								isNewSetUp: true
							}
							Window.show()
						else
							# Didn't complete installation, so close window and quit the app
							@props.closeWindow()
							Window.quit()

		_login: (userName, password) ->
			console.log "Beginning login sequence..."
			console.time 'loginSequence'

			Async.series [
				(cb) =>
					@setState {isLoading: true, loadingMessage: "Authenticating..."}

					# Create session
					Persist.Session.login Config.dataDirectory, userName, password, (err, session) =>
						if err
							cb err
							return

						# Store the session globally
						global.ActiveSession = session
						cb()

				(cb) =>
					@setState {loadingMessage: "Decrypting Data..."}

					openWindow {page: 'clientSelection'}, (newWindow) =>
						clientSelectionPageWindow = newWindow

						# Add listener to close loginPage when clientSelectionPage is closed
						clientSelectionPageWindow.on 'closed', =>
							@props.closeWindow()
							Window.quit()

						# Finish series and hide loginPage once loaded event fires
						global.ActiveSession.persist.eventBus.once 'clientSelectionPage:loaded', cb

			], (err) =>
				@setState {isLoading: false, loadingMessage: ""}

				if err
					if err instanceof Persist.Session.UnknownUserNameError
						@refs.ui.onLoginError('UnknownUserNameError')
						return

					if err instanceof Persist.Session.InvalidUserNameError
						@refs.ui.onLoginError('InvalidUserNameError')
						return

					if err instanceof Persist.Session.IncorrectPasswordError
						@refs.ui.onLoginError('IncorrectPasswordError')
						return

					if err instanceof Persist.Session.DeactivatedAccountError
						@refs.ui.onLoginError('DeactivatedAccountError')
						return

					CrashHandler.handle err
					return

				console.timeEnd 'loginSequence'
				console.log "Successfully logged in!"
				Window.hide()


	LoginPageUi = React.createFactory React.createClass
		displayName: 'LoginPageUi'
		mixins: [React.addons.PureRenderMixin]
		getInitialState: ->
			return {
				userName: ''
				password: ''
			}

		componentDidMount: ->
			setTimeout(=>
				@props.activateWindow()

				if @props.isNewSetUp
					@setState {userName: 'admin'}
					@refs.passwordField.focus()
			, 350)

		onLoginError: (type) ->
			switch type
				when 'UnknownUserNameError'
					Bootbox.alert "Unknown user name. Please try again.", =>
						setTimeout(=>
							@refs.userNameField.focus()
						, 100)
				when 'InvalidUserNameError'
					Bootbox.alert "Invalid user name. Please try again.", =>
						@refs.userNameField.focus()
						setTimeout(=>
							@refs.userNameField.focus()
						, 100)
				when 'IncorrectPasswordError'
					Bootbox.alert "Incorrect password. Please try again.", =>
						@setState {password: ''}
						setTimeout(=>
							@refs.passwordField.focus()
						, 100)
				when 'DeactivatedAccountError'
					Bootbox.alert "This user account has been deactivated.", =>
						@refs.userNameField.focus()
						setTimeout(=>
							@refs.userNameField.focus()
						, 100)
				when 'IOError'
					Bootbox.alert "Please check your network connection and try again."
				else
					throw new Error "Invalid Login Error"

		render: ->
			return R.div({className: 'loginPage'},
				Spinner({
					isVisible: @props.isLoading
					isOverlay: true
					message: @props.loadingMessage
				})
				R.div({id: "loginForm"},
					R.div({
						id: 'logoContainer'
						className: 'animated fadeInDown'
					},
						R.img({
							className: 'animated rotateIn'
							src: 'img/konode-kn.svg'
						})
					)
					R.div({
						id: 'formContainer'
						className: 'animated fadeInUp'
					},
						R.div({className: 'form-group'},
							R.input({
								className: 'form-control'
								autoFocus: true
								ref: 'userNameField'
								onChange: @_updateUserName
								onKeyDown: @_onEnterKeyDown
								value: @state.userName
								type: 'text'
								placeholder: 'Username'
							})
						)
						R.div({className: 'form-group'},
							R.input({
								className: 'form-control'
								type: 'password'
								ref: 'passwordField'
								onChange: @_updatePassword
								onKeyDown: @_onEnterKeyDown
								value: @state.password
								placeholder: 'Password'
							})
						)
						R.div({className: 'btn-toolbar'},
							## TODO: Password reminder
							# R.button({
							# 	className: 'btn btn-link'
							# 	onClick: @_forgotPassword
							# }, "Forgot Password?")
							R.button({
								className: [
									'btn'
									if @_formIsInvalid() then 'btn-primary' else 'btn-success animated pulse'
								].join ' '
								type: 'submit'
								disabled: @_formIsInvalid()
								onClick: @_login
							}, "Sign in")
						)
					)
				)
			)

		_quit: ->
			win.close(true)

		_updateUserName: (event) ->
			@setState {userName: event.target.value}

		_updatePassword: (event) ->
			@setState {password: event.target.value}

		_onEnterKeyDown: (event) ->
			@_login() if event.which is 13 and not @_formIsInvalid()

		_formIsInvalid: ->
			not @state.userName or not @state.password

		_login: (event) ->
			@props.login(@state.userName, @state.password)


	return LoginPage

module.exports = {load}
