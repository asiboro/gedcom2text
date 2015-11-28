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

## Prerequisite
Get gedcom-ruby from [http://gedcom-ruby.sourceforge.net/](http://gedcom-ruby.sourceforge.net/) and install (in gedcom-ruby directory do "ruby extconf.rb; make; sudo make install"). On Mac, make sure command line tools (get from [https://developer.apple.com/downloads/](https://developer.apple.com/downloads/)) are installed.
