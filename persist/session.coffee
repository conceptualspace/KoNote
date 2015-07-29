# This module handles all logic related to login sessions, including logging
# in, logging out, and managing encryption keys.

Async = require 'async'
Fs = require 'fs'
Path = require 'path'
Config = require '../config'

{SymmetricEncryptionKey} = require './crypto'
DataModels = require './dataModels'
Users = require './users'

login = (dataDir, userName, password, cb) ->
	Users.readAccount dataDir, userName, password, (err, account) ->
		if err
			cb err
			return

		cb null, new Session(
			account.userName
			account.accountType
			account.globalEncryptionKey
			dataDir
		)

class Session
	constructor: (@userName, @accountType, @globalEncryptionKey, @dataDirectory) ->
		unless @globalEncryptionKey instanceof SymmetricEncryptionKey
			throw new Error "invalid globalEncryptionKey"

		unless @accountType in ['normal', 'admin']
			throw new Error "unknown account type: #{JSON.stringify @_accountType}"

		@_ended = false

		@persist = DataModels.getApi(@)

		@timeoutMins = Config.timeout.totalMins
		@warningMins = Config.timeout.warningMins

		@resetTimeout()

	resetTimeout: ->
		# Clear all traces of timeouts
		if @warning then clearTimeout @warning
		if @timeout then clearTimeout @timeout
		@timeout = null
		@warning = null

		# Keeping track of notification delivery to prevent duplicates
		@firstWarningDelivered = null
		@minWarningDelivered = null

		# Initiate timeouts
		@warning = setTimeout @_timeoutWarning, (@timeoutMins - @warningMins) * 60000
		@timeout = setTimeout @_timedOut, @timeoutMins * 60000

	_timeoutWarning: => @persist.eventBus.trigger 'timeout:initialWarning'

	_timedOut: => @persist.eventBus.trigger 'timeout:timedOut'

	isAdmin: ->
		return @accountType is 'admin'

	confirmPassword: (password, cb) ->
		Users.readAccount @dataDirectory, @userName, password, (err, account) ->
			if err
				cb err
				return false

			cb()

	logout: ->
		if @_ended
			throw new Error "session has already ended"

		@_ended = true
		@globalEncryptionKey.erase()

module.exports = {
	login
	UnknownUserNameError: Users.UnknownUserNameError
	IncorrectPasswordError: Users.IncorrectPasswordError
}
