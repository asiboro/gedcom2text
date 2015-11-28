#! /usr/bin/env ruby
#
# Converts a GEDCOM file into a text-based descendant chart
# 
#
# By March 2015 by Arnold P. Siboro
# Used parts of gedcom2dot originally written Oct 8, 2007 by Stonewall Ballard
#
# Related sources:
#
# GEDCOM to Graphviz
# http://stoney.sb.org/wordpress/2007/10/gedcom-to-graphviz/
# 
# Matthew Gray's blog entry 
# http://www.mkgray.com:8000/blog/Personal/Family-Tree-Graphing.html
#
# Based on examples from gedcom-ruby <http://gedcom-ruby.sourceforge.net/>, which is required for operation.
#


require 'gedcom'
require 'getoptlong'

$verbose=0

# family separator is an extra line to mark the end of one family (i.e., parent(s) and children)
$withfamilyseparator=0 

$HELP_TEXT = <<-HELPEND
#{$0} convertes a GEDCOM file into text-based pedigree chart
Command: #{$0} opts gedfile
dot file is written to stdout
Options:
  --root Fxxx|Ixxx    Sets root Family or Individual to argument and prunes away unrelated people
  --children          Shows children in every related family if root is set
  --blood             Shows only blood relatives of root
HELPEND

class Person
	attr_accessor :id
	attr_accessor :name
	# the family of which this person is a parent
	attr_accessor :parent_family
	# the family of which this person is a child
	attr_accessor :child_family
	attr_accessor :marked
	
	def initialize( id = nil, name = nil, parent_family = nil, child_family = [], marked = nil )
		@id, @name, @parent_family, @child_family, @marked = id, name, parent_family, child_family, marked
	end
end

class Family
	attr_accessor :id
	attr_accessor :parents
	attr_accessor :children
	attr_accessor :marked

	def initialize( id = nil, parents = [], children = [], marked = nil )
		@id, @parents, @children, @marked = id, parents, children, marked
	end
end

class DotMaker < GEDCOM::Parser
	attr_reader :individuals
	attr_reader :families


	######################################################
	# THE GEDCOM PARSER
	######################################################

	def initialize( root_entity, show_children, show_blood, use_initials)
		@root_entity, @show_children, @show_blood = root_entity, show_children, show_blood, use_initials

		super()

		@current_person = nil
		@current_family = nil
		@people = {}
		@families = {}
# root_entity is set as argument to this program, either an individual (I...) or family (F...)
# here root_is_family is set to true when the argument starts with an F
		@root_is_family = @root_entity =~ /\AF/

# explanation about setPreHandler and setPostHandler can be found here:
# https://github.com/binary011010/gedcom-ruby/blob/master/README
		setPreHandler	 [ "INDI" ], method( :start_person )
		setPreHandler	 [ "INDI", "NAME" ], method( :register_name )
		setPreHandler	 [ "INDI", "FAMC" ], method( :register_parent_family )
		setPreHandler	 [ "INDI", "FAMS" ], method( :register_child_family )
		setPostHandler [ "INDI" ], method( :end_person )

		setPreHandler	 [ "FAM" ], method( :start_family )
		setPreHandler	 [ "FAM", "HUSB" ], method( :register_parent )
		setPreHandler	 [ "FAM", "WIFE" ], method( :register_parent )
		setPreHandler	 [ "FAM", "CHIL" ], method( :register_child )
		setPostHandler [ "FAM" ], method( :end_family )

	end

	def cid( idv )
		id = idv.delete("@")
		return nil if id == "I-1"
		id
	end

	def start_person( data, state, parm )
# set current person to the ID of the person (without the "@")
		@current_person = Person.new cid( data )
		#$stderr.puts  "Start person registration: #{@current_person.id}"
	end

	def register_name( data, state, parm )
# if a person has other names, previous name will be overwritten with this function, so if previous name exists, skip registering name
# other names seem to be unsupported by GEDCOM, but exists in GEDCOM file exported by MacFamilyTree
		if @current_person.name then 
			#$stderr.puts  " >> This is other name of \"" + @current_person.name + "\", so omit: " + data
		else
			@current_person.name = data
			#$stderr.puts  " >> " + @current_person.name;
		end
		#$stderr.puts  "Person's name registered: #{@current_person.name}"
	end
	
	def register_parent_family( data, state, parm )
		@current_person.parent_family = cid data
		#$stderr.puts  "Person's parent family registered: #{@current_person.parent_family}"
	end

	def register_child_family( data, state, parm )
		@current_person.child_family.push cid data
		#$stderr.puts  "Person's child family registered: #{@current_person.child_family}"
	end

	def end_person( data, state, parm )
		@people[@current_person.id] = @current_person
		#$stderr.puts "#{@people[@current_person.id].name}"
# mark person if person is not root entity
		@current_person.marked = @root_entity == nil
		if @current_person.marked then $stderr.puts "person marked (root entity): #{@root_entity} #{@current_person.name}" 					end
		@current_person = nil
		#$stderr.puts  "End person's registration"
	end

	def start_family( data, state, parm )
		@current_family = Family.new cid( data )
	end

	def register_parent( data, state, parm )
		# a parent may be missing (@I-1@)
		d = cid data
		@current_family.parents.push d if d
	#	$stderr.puts "@current_family.parents: #{@current_family.parents} #{@current_family.parents.size}"
	end
	
	def register_child( data, state, parm )
		@current_family.children.push cid( data )
	end
	
	def end_family( data, state, parm )
		@families[@current_family.id] = @current_family
		@current_family.marked = @root_entity == nil
		@current_family = nil
	end
	
	def mark_parents(person)
		unless person.marked
			person.marked = true
			fid = person.parent_family
			if fid
				f = @families[fid]
				f.marked = true
				f.parents.each { |p| mark_parents( @people[p] ) }
				if @show_children
					f.children.each { |c| @people[c].marked = true }
				elsif @show_blood
					f.children.each { |c| mark_children @people[c] }
				end
			end
		end
	end
	
	def mark_children(person)
		unless person.marked
			person.marked = true
			fid = person.child_family
			#if fid then $stderr.puts "person.child_family for #{person.name}: #{fid}" end
			if fid
				f = @families[fid]
				f.marked = true
				f.children.each { |c| mark_children( @people[c] ) }
			end
		end
	end

	# Mark families to be included in the graph
	def mark_family(family)
		family.marked = true
		family.parents.each { |p| mark_parents( @people[p] ) }
		family.children.each { |c| mark_children( @people[c] ) }
	end
	
	def trim_tree
		# mark every individual and family appropriately related to the root family or person
		if @root_entity
			if @root_is_family
				root_family = @families[@root_entity]
				unless root_family
					$stderr.puts "No family id = #{@root_entity} found"
					exit(0)
				end
				mark_family root_family
			else
				root_person = @people[@root_entity]
				unless root_person
					$stderr.puts "No person id = #{@root_entity} found"
					exit(0)
				end
				mark_parents root_person
				root_person.marked = false
				mark_children root_person
			end
		end
	end
	######################################################



	# Create a compact name to be used on node's label
	def createlabelname(name)		

		splitname=name.split("/")
		for i in 1..splitname.length do
			# If the name is within brackets, then actual name of the person is unknown
			if(splitname[i-1] =~ /^\(.+\)/) 
				splitname[i-1] = "(....) " 
			end
		end	
			
		name=splitname.join("")

		# Initialize long name
		splitname=name.split(" ")
		for i in 1..splitname.length do
			# If there are more than 2 names, and this is not 1st name or last name, and it is not already initialized, and this is not 2nd name while the first name is a title such as "Ompu"
			if(splitname.length>2 && i != 1 && i != splitname.length && !(i==2 && (splitname[0].strip=="Ompu" || splitname[0].strip=="O." || splitname[0].strip=="Amani"|| splitname[0].strip=="A." || splitname[0].strip=="Aman" || splitname[0].strip=="Datu" || splitname[0].strip=="Nai" || splitname[0].strip=="Apa" || splitname[0].strip=="Pu" || splitname[0].strip=="Na" || splitname[0].strip=="Boru" || splitname[0].strip=="Apa" || splitname[0].strip=="Raja")) )
					splitname[i-1] = splitname[i-1][0,1].capitalize + "."
			end	
		end

		for i in 1..splitname.length do
# If this name is not an initial (ended by "."), or if it is an initial but before a non-initial
			if(splitname[i-1] && splitname[i])
				if(splitname[i-1][-1,1] != "." || (splitname[i-1][-1,1] == "." && splitname[i][-1,1] != "."))
					splitname[i-1]=splitname[i-1] + " "
				end
			end
		end

		name=splitname.join("")

		label= name	
		return label
	end # createlabelname

	
	def report
		$stderr.puts "Found #{@people.length} people and #{@families.length} families"
	end

	$generation_indent=""
	# generation number starts from 1 (i.e., the first generation in the family tree)
	$generation_number=1
	$family_separation=0
	$parent_is_last_sibling=0


	def outputdescendant(person,child_no,parent_child_no,parent_siblings,parentfamilies,parentfamily_no)

	# person: the specified person
	# child_no: the child number of this person
	# parent_child_no: the child number of this person's parent
	# parent_siblings: the no. of siblings of this person's parent (including this person's parent)
	# parentfamilies: the no. of families the person has

		currentperson = @people[person]
		#$stderr.puts "begin currentperson.name: #{currentperson.name}"
		#$stderr.puts "currentperson: #{person}"
		
		# count the no. of siblings of this person
		if (@families[currentperson.parent_family]) then 
			no_of_siblings = @families[currentperson.parent_family].children.size #current person's no. of siblings
			#$stderr.puts "siblings: #{@families[currentperson.parent_family].children.size}" 
		end


		######################################################
		# WRITE THE PERSON'S NAME
		######################################################
		# if the person is the first person in this family tree
		if ($generation_number==1)then 
			$stderr.puts "#{currentperson.name.delete("/")} (#{$generation_number})" 

		# if the person is NOT the first person in this family tree
		else
#			$stderr.puts "#{@generation_indent}|-#{createlabelname(currentperson.name)} (#{$generation_number}) fams: #{currentperson.child_family.size}" 
			$stderr.puts "#{@generation_indent}|-#{createlabelname(currentperson.name)} (#{$generation_number})" 
		end #$generation_number>0
		# since a non-separator line (i.e., name of the person) has been written, 
		# so set $prev_familyseparator to 0
		$prev_familyseparator=0
		
		######################################################
		# WRITE THE PERSON'S WIFE AND CHILDREN, IF ANY
		######################################################
		# if the person has one or more child families (i.e., is married)
		if(currentperson.child_family) then 
			numberofchildfams=currentperson.child_family.size
			anyfamilyhaschildren=0
			#$stderr.puts "#{@generation_indent}** #{currentperson.name.delete("/")} has #{numberofchildfams} families"

			# go through each familiy
			currentperson.child_family.each_with_index do |thechildfamily,i|
				#$stderr.puts "#{currentperson.name} i+1=#{i+1}"
				# initialize separator counter to none as we start to go through a new family
				$prev_familyseparator=0

				#$stderr.puts "#{@generation_indent}** No. of children: #{@families[thechildfamily].children.size}"
				numberofchildren=@families[thechildfamily].children.size

				######################################################
				# WRITE THE WIFE'S NAME
				######################################################
				# write the the name of this person's wifes in this particular child_family
				# this person is the first person in this family tree
				if ($generation_number==1)then 

					# write the the name of this person's wife in this particular child_family
					@families[thechildfamily].parents.each do |theparents|
						if(theparents!=person) then 
							@currentwife=@people[theparents] 
							$stderr.puts "#{@generation_indent}|   + #{createlabelname(@currentwife.name)}" 
						end
					end
				# this person is NOT the first person in this family tree
				else

					#$stderr.puts "#{person} - #{@families[currentperson.child_family].parents}" 

					# write the the name of this person's wife in this particular child_family
					@families[thechildfamily].parents.each do |theparents|
						if(theparents!=person) then 
							@currentwife=@people[theparents] 

							# adjust the vertical bars
							# if this family has children
							if(numberofchildren>0) then
								if(child_no==no_of_siblings && parentfamily_no==parentfamilies)	then 
									$stderr.puts "#{@generation_indent}  |  + #{createlabelname(@currentwife.name)}" 
								else 
									$stderr.puts "#{@generation_indent}| |  + #{createlabelname(@currentwife.name)}" 
								end
							# if this family has NO children
							else
								if(child_no==@no_of_siblings)	then 
									$stderr.puts "#{@generation_indent}     + #{createlabelname(@currentwife.name)}" 
								else 
									$stderr.puts "#{@generation_indent}| |  + #{createlabelname(@currentwife.name)}" 
								end	
							end

						end #if(theparents!=person)
					end #do |theparents|

					# a non-blank line is written above, so reset family separator counter so that family separator (blank line) can be added after this when necessary
					if($prev_familyseparator>=1) then $prev_familyseparator -=1 end

				end #$generation_number>0
				######################################################



				#$stderr.puts "parentfamilies before #{parentfamilies}"

				######################################################
				# WRITE THE CHILDREN'S NAMEs
				######################################################

				if(numberofchildren>0) then

					anyfamilyhaschildren=1

					# do generation indentation (two spaces) if there are children in this family
					#$stderr.puts "#{parentfamily_no}/#{parentfamilies}"
					if ($generation_number>1)then 
						#$stderr.puts "child_no=#{child_no}, no_of_siblings=#{no_of_siblings} i=#{i} fams=#{numberofchildfams}"
						
						if(child_no == no_of_siblings && i+1 == numberofchildfams && parentfamily_no==parentfamilies) then # if this is the last sibling, in the last family, then do not extend the vertical line
							@generation_indent="#{@generation_indent}"+"  "
						else
							@generation_indent="#{@generation_indent}"+"| "
						end
					end
					generation_number = $generation_number += 1 # increase generation number
				

				
					# now, go to each of the children
					@families[thechildfamily].children.each_with_index do |thechildren,j|
						#$stderr.puts "#{thechildren} out of #{@families[thechildfamily].children}"

						# outputdescendant(person,child_no,parent_child_no,siblings,parentfamilies,parentfamily_no)
						outputdescendant(thechildren,j+1,child_no,no_of_siblings,numberofchildfams, i+1)

						#if(j+1==numberofchildren) then $stderr.puts "#{j+1}" end
						#$stderr.puts "#{@generation_indent} #{j+1} #{numberofchildren}"
					end	

					#$stderr.puts "parentfamilies after #{parentfamilies}"

					# if there is no previous family separator, then add one now
					if($withfamilyseparator && $prev_familyseparator==0) then 
						# if this person has only one family, or last family in multiple families, 
						# then stop descendant line here
						if(numberofchildfams==1 || i+1==numberofchildfams) then
							$stderr.puts "#{@generation_indent}" 
						end
						# if this person has multiple families and this is NOT the last family
						# then continue descendant line
						if(numberofchildfams>1 && i+1!=numberofchildfams)
							# bar is necessary if this is the last family among multiple families
							$stderr.puts "#{@generation_indent}|"
						end
						# family separator is added, so set prev_familyseparator to true so that 
						# another separator is not added right after this one
						$prev_familyseparator +=1													
					end
				else # if no children
					# if there is no previous family separator, then add one now
					if($withfamilyseparator && $prev_familyseparator==0) then 
						# if this person is the last child and has only one family
						if(child_no==no_of_siblings && numberofchildfams==1) then
							$stderr.puts "#{@generation_indent}"
						end
						# if this person is NOT the last child and has only one family
						if(child_no!=no_of_siblings && numberofchildfams==1) then
							$stderr.puts "#{@generation_indent}|"
						end
						# if this person is NOT the last child and has more than one family
						if(child_no!=no_of_siblings && numberofchildfams>1) then
							$stderr.puts "#{@generation_indent}| |"
						end
						# family separator is added, so set prev_familyseparator to true so that 
						# another separator is not added right after this one
						$prev_familyseparator +=1													
					end						
				end #if(numberofchildren>0)
				######################################################


				#all children in this family is written out, so remove one generation indentation

				#$stderr.puts "childfam: #{i+1}/#{numberofchildfams} numberofchildren:#{numberofchildren} anyfamilyhaschildren:#{anyfamilyhaschildren}"

				# if this person has only one family and there are children
				# or if this person has more than one family at least one of the families has children and the last family is not without children
				if((numberofchildfams==1 && numberofchildren!=0) || (numberofchildfams!=1 && anyfamilyhaschildren==1 && numberofchildren!=0)) then 
					#$stderr.puts "#{@generation_indent}remove one indentation (currently at person #{currentperson.name.delete("/")}"
					generation_number = $generation_number -= 1 #finished listing up children, go back up one generation
					if(@generation_indent) then
						#$stderr.puts "remove one @generation_indent" 
						@generation_indent=@generation_indent[0..-3] # remove generation indentation (i.e., two spaces)
					end
				end #remove one indentation 

			end #currentperson.child_family.each

		end #if(currentperson.child_family)	

		#$stderr.puts "end currentperson.name: #{currentperson.name}"

	end #outputdescendant()



	

	def export
		$stderr.puts "Exporting..."
		#puts "digraph familyTree {"

		if @root_is_family
			$stderr.puts "Root is a family"
			# color the root family red
		end
		
		$stderr.puts "root: #{@root_entity}"
		outputdescendant(@root_entity,1,1,1,0,1)
	end

end #class DotMaker < GEDCOM::Parser



######################################################
# MAIN PROGRAM
######################################################

opts = GetoptLong.new(
  ["--root", "-r", GetoptLong::REQUIRED_ARGUMENT],
  ["--children", "-c", GetoptLong::NO_ARGUMENT],
	["--blood", "-b", GetoptLong::NO_ARGUMENT],
	["--initials", "-i", GetoptLong::NO_ARGUMENT],
  ["--help", "-h", GetoptLong::NO_ARGUMENT]
)

root_entity = nil
show_children = nil
show_blood = nil
use_initials= nil



opts.each do |opt, arg|
	case opt
	when "--root"
		root_entity = arg.upcase
		unless root_entity =~ /\A(F|I)\d+\z/
			$stderr.puts "--root argument must be F or I followed by digits, like F123 or I4"
			exit(1)
		end
	when "--children"
		show_children = true
	when "--blood"
		show_blood = true
	when "--initials"
		use_initials = true
	when "--help"
		puts $HELP_TEXT
		exit(0)
	end
	if show_children && show_blood
		puts "Only one of --children and --blood can be specified"
		exit(1)
	end
end

if ARGV.length < 1
	$stderr.puts "Please specify the name of a GEDCOM file."
	exit(1)
end

parser = DotMaker.new( root_entity, show_children, show_blood, use_initials)

parser.parse ARGV[0]

# remove all the people unrelated to the root person or family if set
#parser.trim_tree if root_entity

# export the dot file
parser.export
parser.report

