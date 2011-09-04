#!/usr/bin/env ruby
%w{rubygems bundler/setup helpers oauth json}.each { |gem| require "#{gem}" }

class Rubident
	
	def initialize
		# All available services will reside in:
		@service = Hash.new
		
		%w{sites accounts}.each do |f|
			begin
				# Try to open existing file
				file = File.open("#{ENV["HOME"]}/.config/rubident/#{f}", "r")
				file.close
			rescue	# Dir or File not found
				# Create
				begin
					# Try to open directory
					Dir.entries("#{ENV["HOME"]}/.config/rubident")
				rescue
					# Create
					Dir.mkdir("#{ENV["HOME"]}/.config/rubident")
				end
				file = File.new("#{ENV["HOME"]}/.config/rubident/#{f}", "a+")
				file.close
			end
		end
		
		# Recognised services are stored in 'rubident-keys'
		puts "Reading supported services... "
		globals = File.open("#{ENV['HOME']}/.config/rubident/sites", "r") { |f| f.read }	# auto-close
		globals = globals.split("\n")
		globals.each do |line|
			parts = line.split(" ")
			@service["#{parts[0]}"] = {
				"site"   			=> "#{parts[0]}",
				"key"    			=> "#{parts[1]}",
				"secret" 			=> "#{parts[2]}",
				"name"   			=> "#{parts[3]}",
				"registered" 	=> false
			}

			# While the API may be compatible, each service may differ
			if parts[0] =~ /twitter/
				@service["#{parts[0]}"]["path"] = "/oauth"
				@service["#{parts[0]}"]["request_path"] = "/1"
			elsif parts[0] =~ /identi/
				@service["#{parts[0]}"]["path"] = "/api/oauth"
				@service["#{parts[0]}"]["request_path"] = "/api"
			end
		end
		
		@service.each do |s,v|
			if v["site"] == s then
				puts " - found: #{v["name"]} [#{s}]"
			else
				puts " - error reading #{s}"
			end
		end

		# Registered services are stored in 'rubident'
		puts "\nReading your account details... "
		locals = File.open("#{ENV['HOME']}/.config/rubident/accounts", "r") { |f| f.read }	# auto-close
		locals = locals.split("\n")
		locals.each do |s|
			keys = s.split(" ")
			site = keys[0]
			@service["#{site}"]["consumer_key"] = keys[1]
			@service["#{site}"]["consumer_sec"] = keys[2]
			@service["#{site}"]["registered"] = true
		end

		@service.each do |s,v|
			if v["site"] == s && v["registered"] == true then
				puts " - found: #{v["name"]} [#{s}] => #{v["path"]}"
			elsif v["site"] == s && v["registered"] == false then
				puts " - (new): #{v["name"]} [#{s}] => #{v["path"]}"
			else
				puts " - error: #{v["name"]} [#{s}]"
			end
		end

		return @service
	end
	
	def setup
		# Enter the base URL of the service, from which the API URL will be constructed
		# e.g. "twitter.com" not "api.twitter.com"
		print "\nURL of service: http://"
		
		site = STDIN.readline.chomp
		    if site =~ /twitter/
			site = "#{@service["https://api.twitter.com"]["site"]}"
		elsif site =~ /ident/
			site = "#{@service["https://identi.ca"]["site"]}"
		else
			puts "#{site} is not recognised. Contact the developers if you would like to request support for this service."
			exit 0
		end
		
		puts "Contacting #{@service["#{site}"]["name"]} at #{@service["#{site}"]["path"]}/authorize..."
		consumer = OAuth::Consumer.new(
			@service["#{site}"]["key"],
			@service["#{site}"]["secret"],
			:site               =>	"#{@service["#{site}"]["site"]}",
			:authorize_path     =>  "#{@service["#{site}"]["path"]}/authorize",
			:request_token_path	=>  "#{@service["#{site}"]["path"]}/request_token",
			:access_token_path  =>  "#{@service["#{site}"]["path"]}/access_token",
			:http_method        =>  :get
		)
		
		request_token = consumer.get_request_token
		
		puts "
	To set-up rubident, open your web browser and sign in to #{@service["#{site}"]["name"]}. Authorise rubident by visiting:
		#{request_token.authorize_url}

	Enter the code: "
		pin = STDIN.readline.chomp
		
		@access_token = request_token.get_access_token(:oauth_verifier => pin)
		
		file = File.new("#{ENV['HOME']}/.config/rubident/accounts", "a+")
		file.write("#{@service["#{site}"]["site"]} #{@access_token.token} #{@access_token.secret}\n")
		file.close
	end

	def select_service
		# How many available services are in 'rubident-keys' ?
		if @service.length < 1
			puts "You don't have any services set up. Please create the 'rubident-keys' file."
		elsif @service.length == 1
			puts "Using your default account."
			@service = @service.first
		else
			puts "\nSelect your service:"
			selection = []
			count = 1
			@service.each do |s, v|
				puts " #{count}) #{v["name"]}"
				selection[count - 1] = v["site"]
				count += 1
			end
		choice = Integer(STDIN.readline.chomp)
		@service = @service["#{selection[choice - 1]}"]
		end

		# At this point we should have one service, default or selected
		puts "#{@service["name"]} (#{@service["site"]}) selected.\n"
		
		consumer = OAuth::Consumer.new(
			@service["key"],
			@service["secret"],
			:site               =>  "#{@service["site"]}",
			:authorize_path     =>  "#{@service["path"]}/authorize",
			:request_token_path	=>  "#{@service["path"]}/request_token",
			:access_token_path  =>  "#{@service["path"]}/access_token",
			:http_method        =>	:get
		)

		# Read and writes will be done through this access token
		@access_token = OAuth::AccessToken.new(consumer, @service["consumer_key"], @service["consumer_sec"])

		return @service
	end

	def post
		# Posting a message to the account
		url = "#{@service["site"]}#{@service["request_path"]}/account/verify_credentials.json"
		me = @access_token.get(url)
		my = JSON.parse(me.body)
		coords = my["status"]["geo"].first.last ||= Array.new("","")

		# Send the update
		update = @access_token.post(
			"#{@service["site"]}#{@service["request_path"]}/statuses/update.json",
			"status" => ARGV[1],
			"lat"    => coords.first,
			"long"   => coords.last,
			"source" => "rubident"
		).body
		
		# TODO: response !
	end
	
	def post_dm
		# Posting private/direct message to an account
		url = "#{@service["site"]}#{@service["request_path"]}/account/verify_credentials.json"
		me = @access_token.get(url)
		my = JSON.parse(me.body)
		coords = my["status"]["geo"].first.last ||= Array.new
		
		# Send the update
		update = @access_token.post(
			"#{@service["site"]}#{@service["request_path"]}/direct_messages/new.json",
			"screen_name" => ARGV[1],
			"text"	 			=> ARGV[2]
		).body
		
		# TODO: response !
	end
	
	def home
		# load and display cache
#		if cache = File.open("#{ENV['HOME']}/.rubident-caches-#{@service["consumer_key"]}-home.json", "r") { |c| c.read } then
#			cache.reverse.each do |c|
#				puts "\n #{c["user"]["name"]} says:\n\t#{c["text"]}\n"
#			end
#		end
		url = "#{@service["site"]}#{@service["request_path"]}/statuses/home_timeline.json"
		data = @access_token.get(url)
		json = JSON.parse(data.body)
		json.reverse.each do |p|
			puts "\n #{p["user"]["name"]} (@#{p["user"]["screen_name"]}) said #{Helpers.format_timestamp p["created_at"]}:\n\t#{p["text"]}\n"
		end
#		# Save to cache
#		file = File.new("#{ENV['HOME']}/.rubident-caches-#{@service["consumer_key"]}-home.json", "a+")
#		file.write(json)
#		file.close
	end
	
	def replies
		url = "#{@service["site"]}#{@service["request_path"]}/statuses/replies.json"
		data = @access_token.get(url)
		json = JSON.parse(data.body)
		json.reverse.each do |p|
			puts "\n #{p["user"]["name"]} says:\n\t#{p["text"]}\n"
		end
	end
	
	def inbox
		url = "#{@service["site"]}#{@service["request_path"]}/direct_messages.json"
		data = @access_token.get(url)
		json = JSON.parse(data.body)
		json.reverse.each do |p|
			puts "\n #{p["sender"]["name"]} (@#{p["sender"]["screen_name"]}) said #{Helpers.format_timestamp p["created_at"]}:\n\t#{p["text"]}\n"
		end
	end
	
	def outbox
		url = "#{@service["site"]}#{@service["request_path"]}/direct_messages/sent.json"
		data = @access_token.get(url)
		json = JSON.parse(data.body)
		json.reverse.each do |p|
			puts "\n You said to #{p["sender"]["name"]} (@#{p["sender"]["screen_name"]}):\n\t#{p["text"]}\n"
		end
	end
	
	def public
		url = "#{@service["site"]}#{@service["request_path"]}/statuses/public_timeline.json"
		data = @access_token.get(url)
		json = JSON.parse(data.body)
		json.reverse.each do |p|
			puts "\n #{p["user"]["name"]} (@#{p["user"]["screen_name"]}) said #{Helpers.format_timestamp p["created_at"]}:\n\t#{p["text"]}\n"
		end
	end
	
end

client = Rubident.new

if $0.include? "rubident.rb"
	if 				ARGV[0] == "setup" 		then client.setup
	else			client.select_service
		if 			ARGV[0] == "post" 		then client.post
		elsif 	ARGV[0] == "post-dm" 	then client.post_dm
		elsif 	ARGV[0] == "home" 		then client.home
		elsif 	ARGV[0] == "replies"	then client.replies
		elsif 	ARGV[0] == "inbox"		then client.replies
		elsif 	ARGV[0] == "outbox"		then client.replies
		elsif 	ARGV[0] == "public"		then client.public
		end
	end
end
