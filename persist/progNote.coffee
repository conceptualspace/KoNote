# Defines the ProgNote data structure used for storing progress notes.
#
# There are two types of progress notes: basic and full.  Basic progress notes
# are called "Quick Notes" in the UI.  They consist of just a single text area.
#
# Full progress notes are built from a template.  The template determines what
# sections the progress note should contain.  There are two types of sections:
# basic and plan.  A basic section has a name (determined by the template), a
# text area for notes, and zero or more metrics (from the template).  A plan
# section has a name (from the template), and contains one text area for every
# one of the client's plan targets.  This means that the number of text areas
# will vary depending on which client the progress note is for.

Async = require 'async'
Fs = require 'fs'
Joi = require 'joi'
Moment = require 'moment'
Path = require 'path'

ClientFile = require './clientFile'
ObjectUtils = require './object'
{generateId, IdSchema, SafeTimestampFormat} = require './utils'

schema = [
	Joi.object().keys({
		id: IdSchema
		type: 'basic' # aka "Quick Notes"
		clientId: IdSchema
		author: Joi.string() # TODO
		timestamp: Joi.date().iso().raw() # TODO
		notes: Joi.string()
	})
	Joi.object().keys({
		id: IdSchema
		type: 'full'
		clientId: IdSchema
		author: Joi.string() # TODO
		timestamp: Joi.date().iso().raw() # TODO
		templateId: IdSchema
		sections: Joi.array().items(
			[
				Joi.object().keys({
					id: IdSchema
					type: 'basic'
					name: Joi.string()
					notes: [Joi.string(), '']
					metrics: Joi.array().items(
						Joi.object().keys({
							id: IdSchema
							name: Joi.string()
							definition: Joi.string()
							value: [Joi.string(), '']
						})
					)
				})
				Joi.object().keys({
					id: IdSchema
					type: 'plan'
					name: Joi.string()
					targets: Joi.array().items(
						Joi.object().keys({
							id: IdSchema
							name: Joi.string()
							notes: [Joi.string(), '']
							metrics: Joi.array().items(
								Joi.object().keys({
									id: IdSchema
									name: Joi.string()
									definition: Joi.string()
									value: [Joi.string(), '']
								})
							)
						})
					)
				})
			]
		)
	})
]

readAll = (clientId, cb) ->
	ClientFile._getObjectDirectory clientId, (err, clientFileDir) ->
		if err
			cb err
			return

		progNotesDir = Path.join clientFileDir, 'progNotes'
		Fs.readdir progNotesDir, (err, progNoteFileNames) ->
			if err
				# If directory does not exist
				if err.code is 'ENOENT'
					# Nobody has created any prog notes yet
					cb null, []
					return

				cb err
				return

			Async.map progNoteFileNames, (progNoteFileName, cb) ->
				objPath = Path.join progNotesDir, progNoteFileName
				ObjectUtils.read objPath, schema, cb
			, cb

create = (newProgNote, cb) ->
	unless newProgNote.get('id')?
		newProgNote = newProgNote.set 'id', generateId()

	unless newProgNote.get('timestamp')?
		newProgNote = newProgNote.set 'timestamp', Moment().format()

	ClientFile._getObjectDirectory newProgNote.get('clientId'), (err, clientFileDir) ->
		if err
			 cb err
			 return

		progNotesDir = Path.join clientFileDir, 'progNotes'

		ts = Moment(newProgNote.get('timestamp')).format(SafeTimestampFormat)
		progNoteFileName = "#{ts}.#{newProgNote.get('id')}"

		objPath = Path.join progNotesDir, progNoteFileName
		ObjectUtils.write newProgNote, objPath, schema, (err, result) ->
			if err
				cb err
				return

			global.EventBus.trigger 'newProgNote', result
			cb null, result

module.exports = {readAll, create}
