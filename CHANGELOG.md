### 1.12.0 (Nov 18 2016)

This release generally improves performance. Startup time is 50% faster and client file loading times are also significantly faster. Responsiveness has been improved throughout, and we've tried to eliminate most sources of latency (such as when navigating between tabs or highlighting items on a chart). We've also made performance more consistent when dealing with very large databases.

#### Improvements

- Faster startup time (#830, #831, #865)
- Faster client file loading time (#671, #800)
- Faster progress note saving time
- Faster transitions between pages and history (#859)
- Events have a singular description instead of both a title and a description (#871)
- Events in analysis can be highlighted (#817)
- Items in the analysis legend include a count for the number of items displayed (#825)
- Plan can be printed as a "cheat sheet" including metric definitions (#781)
- Client information includes additional fields (DOB, Care Providers) (#823)
- Templates have descriptions, and can be viewed from manager layer (#758, #786)
- Various other performance, style and UI improvements 

#### Fixes

- Targets without metrics are no longer displayed in analysis (#815)
- Backdated notes use backdate for default event start date (#888)
- Event end-date defaults to day after start date (#857)
- Datepicker better supports years / decades (#851)
- Events can be edited when editing a progress note (#248)
- Cancelling a progress note cancels associated events (#813)


### 1.11.0

#### Improvements

- Add client information page (#114)
- Support for file attachments in quick notes (#721)
- New UI for plan view (#767, #780)
- Allow reordering of plan sections and targets (#80)
- Nicer formating of printed pages (#808)

#### Fixes

- Fix input latency on new progress note page (#783)
- Apply template without requiring a section (#785)
- Programs can be deactivated (#760)
- Various other fixes and stability improvements