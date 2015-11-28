# **GEDCOM to Text**

**Application name**: gedcom2text  
**Platform**: Ruby  
**Deployment target**: 
**Library**: gedcom-ruby

## Description

This program create a text-based family tree from GEDCOM file.  
Execute like below:

`ruby gedcom2text.rb --root I55101376 all.ged > all.dot`

Where I55101376 is the individual to bet set as root person.  
Use Graphviz viewer to view result.

## Prerequisite
Get gedcom-ruby from [http://gedcom-ruby.sourceforge.net/](http://gedcom-ruby.sourceforge.net/) and install (ruby extconf.rb; make; make install).

