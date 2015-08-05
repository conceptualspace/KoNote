module.exports = {
	productName: 'KoNote'
	customerLogoLg: 'customer-logo-lg_GRIFFIN.png'
	customerLogoSm: 'customer-logo-sm_GRIFFIN.png'
	logoSubtitle: 'DSSS'
	logoSubtitleColor: 'hsl(205, 78%, 47%)'

	clientFileRecordId: {
		isEnabled: true
		label: "CR#"
	}

	# Specify data directory
	dataDirectory: 'data'

	# Set total timeout mins,
	# and how many mins before timeout to show warning
	timeout: {
		totalMins: 25
		warningMins: 15
	}

	# Set terminology to be used around the app, lowercase only
	# * Only modify the values in double-quotes
	# * Terms are auto pluralized & capitalized in term.coffee
	terminology: {
		'user': "user"
		'account': "account"
		'user account': "user account"

		'client': "client"
		'file': "file"
		'client file': "client file"

		'section': "section"
		'plan': "plan"
		'target': "goal"
		'plan target': "plan goal"

		'progress note': "progress note"
		'quick note': "quick note"

		'metric': "indicator"
		'event': "event"

		'analysis': "analysis"
	}		

	# useTemplate: 'initialAssessment'
	useTemplate: 'clientLog'

	# David's demo templates:
	# useTemplate: 'simpleDemoTemplate'
	# useTemplate: 'sectionedDemoTemplate'

	templates: {

		# 2 demo templates for David
		simpleDemoTemplate: {
			id: 'simpleDemoTemplate'
			name: 'Simple Demo Template'
			sections: [
				{
					id: 'notes'
					type: 'basic'
					name: 'Notes'
					metricIds: []
				}
			]
		}
		sectionedDemoTemplate: {
			id: 'sectionedDemoTemplate'
			name: 'Sectioned Demo Template'
			sections: [
				{
					id: 'subjective'
					type: 'basic'
					name: 'Subjective'
					metricIds: []
				}
				{
					id: 'objective'
					type: 'basic'
					name: 'Objective'
					metricIds: []
				}
				{
					id: 'assessment'
					type: 'basic'
					name: 'Assessment'
					metricIds: []
				}
			]
		}

		initialAssessment: {
			id: 'initAssessGC'
			name: 'Client Log - Initial Assessment'
			sections: [
				{
					id: 'peerInt'
					type: 'basic'
					name: 'Peer Interactions'
					metricIds: []
				}
				{
					id: 'staffInt'
					type: 'basic'
					name: 'Staff Interactions'
					metricIds: []
				}
				{
					id: 'partProgramming'
					type: 'basic'
					name: 'Participation in Programming'
					metricIds: []
				}
				{
					id: 'partAcademics'
					type: 'basic'
					name: 'Participation in Academics'
					metricIds: []
				}
				{
					id: 'descGenPres'
					type: 'basic'
					name: 'Description of General Presentation'
					metricIds: []
				}
				{
					id: 'descCoping'
					type: 'basic'
					name: 'Description of Coping Skills Exhibited'
					metricIds: []
				}
				{
					id: 'staffFamily'
					type: 'basic'
					name: 'Staff Contact with Family'
					metricIds: []
				}
				{
					id: 'additional'
					type: 'basic'
					name: 'Additional Comments Related to Domains / General Comments (including incidents, etc)'
					metricIds: []
				}
				{
					id: 'checkin'
					type: 'basic'
					name: 'Feedback from Client Check-In'
					metricIds: []
				}
				{
					id: 'sr'
					type: 'basic'
					name: 'School Readiness'
					metricIds: [
						'sr1'
						'sr2'
						'sr3'
						'sr4'
					]
				}
				{
					id: 'ss'
					type: 'basic'
					name: 'Social Skills'
					metricIds: [
						'ss1'
						'ss2'
						'ss3'
						'ss4'
					]
				}
				{
					id: 'life'
					type: 'basic'
					name: 'Life Skills'
					metricIds: [
						'life1'
						'life2'
					]
				}
				{
					id: 'leisure'
					type: 'basic'
					name: 'Leisure Skills'
					metricIds: [
						'leisure1'
						'leisure2'
					]
				}
			]
		}
		clientLog: {
			id: 'clientLogGC'
			name: 'Client Log'
			sections: [
				{
					id: 'goals'
					type: 'plan'
					name: 'Client Goals'
				}
				{
					id: 'peerInt'
					type: 'basic'
					name: 'Peer Interactions'
					metricIds: []
				}
				{
					id: 'staffInt'
					type: 'basic'
					name: 'Staff Interactions'
					metricIds: []
				}
				{
					id: 'partProgramming'
					type: 'basic'
					name: 'Participation in Programming'
					metricIds: []
				}
				{
					id: 'partAcademics'
					type: 'basic'
					name: 'Participation in Academics'
					metricIds: []
				}
				{
					id: 'descGenPres'
					type: 'basic'
					name: 'Description of General Presentation'
					metricIds: []
				}
				{
					id: 'descCoping'
					type: 'basic'
					name: 'Description of Coping Skills Exhibited'
					metricIds: []
				}
				{
					id: 'staffFamily'
					type: 'basic'
					name: 'Staff Contact with Family'
					metricIds: []
				}
				{
					id: 'additional'
					type: 'basic'
					name: 'Additional Comments'
					metricIds: []
				}
				{
					id: 'checkin'
					type: 'basic'
					name: 'Feedback from Client Check-In'
					metricIds: []
				}
			]
		}
		soap: {
			id: 'fake-template-lolololol'
			name: 'Fake Template'
			sections: [
				{
					id: 'section1'
					type: 'basic'
					name: 'Subjective'
					metricIds: ['score']
				}
				{
					id: 'section2'
					type: 'basic'
					name: 'Objective'
					metricIds: []
				}
				{
					id: 'section3'
					type: 'basic'
					name: 'Assessment'
					metricIds: []
				}
				{
					id: 'section4'
					type: 'plan'
					name: 'Plan'
				}
			]
		}
	}
}

# merge with dev-config; overrides defaults
_ = require 'underscore'
try
	configDev = require './config-dev'
	_.extend(module.exports, configDev)
catch err
	# ignore if dev-config doesn't exist
	if err.code is 'MODULE_NOT_FOUND'
		return
	throw err
