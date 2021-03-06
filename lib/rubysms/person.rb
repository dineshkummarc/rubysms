#!/usr/bin/env ruby
# vim: noet

module SMS
	class Person < Hash
		@@people = {}
		
		def self.fetch(backend, key)
			
			# if a people hash doesn't exist for
			# this backend yet, create one now
			unless @@people.has_key?(backend)
				@@people[backend] = {}
			end
			
			# if a person object doesn't already exist for this key,
			# create one (to be fetched again next time around)
			unless @@people[backend].has_key?(key)
				p = SMS::Person.new(backend, key)
				@@people[backend][key] = p
			end
			
			# return the persistant person,
			# which may or may not be new
			@@people[backend][key]
		end
		
		
		attr_reader :backend, :key
		
		def initialize(backend, key)
			@backend = backend
			@key = key
		end
		
		# Return this person is a vaguely useful
		# way that doesn't look too out of place.
		def to_s
			"#<SMS::Person backend=#{backend.label}, key=#{key}>"
		end
		
		# wat
		def phone_number
			key
		end
	end
end
