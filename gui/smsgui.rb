#!/usr/bin/env ruby

require "libglade2.rb"
require "drb.rb"

SERVER_PORT = "1370"

class SmsGui
	include GetText
	attr :glade
	
	def initialize
		dir = File.dirname(__FILE__)
		@glade = GladeXML.new("#{dir}/smsgui.glade") do |handler|
			method(handler)
		end
		
		# for storing outgoing
		# messages for recall
		@history = []
		@hist_pos = 0
		
		# fetch references to the gtk widgets
		@source = @glade.get_widget("entry_source")
		@entry = @glade.get_widget("entry_message")
		@log = @glade.get_widget("textview_log")
		@lb = @log.buffer
		
		# create a text mark to keep at the end of
		# the log, so we can keep scrolling to it
		@lb.create_mark("end", @lb.end_iter, false)
		
		# create colors for incoming and outgoing messages
		@lb.create_tag("incoming", "family"=>"monospace", "foreground"=>"#AA0000")
		@lb.create_tag("outgoing", "family"=>"monospace", "foreground"=>"#0000AA")
		@lb.create_tag("error", "family"=>"monospace", "foreground"=>"#FFFFFF", "background"=>"#FF0000")
		
		# prepopulate the source phone number with six digits
		@src = (1111 + rand(8888)).to_s
		@source.text = @src
		
		# fire up drb, to send outgoing messages to rubysms
		@injector = DRbObject.new_with_uri("druby://localhost:#{SERVER_PORT}")
		puts "Connected to RubySMS at: #{@injector.__drburi}"
		
		# start listening for incoming messages from rubysms
		@drb = DRb.start_service("druby://localhost:#{SERVER_PORT}#{@src}", self)
		puts "Started DRb client at: #{@drb.uri}"
		
		# display the GUI
		@glade.get_widget("window").show
		@entry.grab_focus
	end
	
	
	# user closed the window,
	# so terminate the program
	def on_quit
		Gtk.main_quit
	end
	
	
	# user clicked "send", or pressed
	# enter while in the entry field
	def on_button_send_clicked
		msg = @entry.text
		
		# do nothing if the message is blank
		return nil if msg.empty?
		log ">> #{msg}", "incoming"

		begin
			# attempt to send the message
			# to rubysms via drb, as if it
			# were a real incoming sms
			@injector.incoming(@src, msg)
			
			@hist_pos = 0
			@history.push(msg)
			@entry.text = ""
		
		# couldn't connect!
		rescue DRb::DRbConnError
			log("Connection to RubySMS failed!", "error")
			#log("Tried URI: #{@injector.__drburi}", "error")
		rescue => err
			log(err.message, "error")
			log("  " + err.backtrace.join("\n  "), "error")
		end
	end
	
	def on_entry_message_key_press(widget, event)
		if event.keyval == 65362 # up arrow
			if @hist_pos > -@history.length
				@hist_pos -= 1
				@entry.text = @history[@hist_pos]
				@entry.grab_focus
			end
			
			# prevent default event,
			# which bumps the focus
			# upwards to the log
			return true
		end
		
		if event.keyval == 65364 # down arrow
			if @hist_pos < -1
				@hist_pos += 1
				@entry.text = @history[@hist_pos]
				@entry.grab_focus
			end
			
			# prevent default
			return true
		end
		
		# any other key resets
		# the position in history
		@hist_pos = 0
		return false
	end
	
	
	def log(msg, tag)
		# prepend a newline, unless this
		# is the first entry (to avoid a
		# one-line gap at the top)
		msg = "\n" + msg\
			if @lb.char_count > 0
		
		# add a single entry to the message log
		# (using the colors defined in #initialize)
		@lb.insert(@lb.end_iter, msg, tag)
		
		# update the position of the end marker
		# (move it to the end!), and scroll to
		# it, to keep the latest text in view
		mark = @lb.get_mark("end")
		@lb.move_mark(mark, @lb.end_iter)
		@log.scroll_to_mark(mark, 0, true, 0, 1)
	end
	
	
	def incoming(msg)
		# we received a message! do nothing
		# except add it to the message log
		msg.gsub!(/\n/, "\n   ")
		log "<< #{msg}", "outgoing"
	end
end


# initialize, and block
# until GTK terminates
gui = SmsGui.new
Gtk.main
