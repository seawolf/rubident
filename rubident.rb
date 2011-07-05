#!/usr/bin/env ruby

%w{rubygems oauth json}.each { |gem| require "#{gem}" }

# All available services will reside in:
service = Hash.new

# Recognised services are stored in 'rubident-keys'
puts "Reading supported services... "
globals = File.open("#{ENV['HOME']}/.rubident-keys", "r") { |f| f.read }	# auto-close
globals = globals.split("\n")
globals.each do |line|
	parts = line.split(" ")
	service["#{parts[0]}"] = {
		"site"   			=> "#{parts[0]}",
		"key"    			=> "#{parts[1]}",
		"secret" 			=> "#{parts[2]}",
		"name"   			=> "#{parts[3]}",
		"registered" 	=> false
	}

	# While the API may be compatible, each service may differ
	if parts[0] =~ /twitter/
		service["#{parts[0]}"]["path"] = "/oauth"
		service["#{parts[0]}"]["request_path"] = "/1"
	elsif parts[0] =~ /identi/
		service["#{parts[0]}"]["path"] = "/api/oauth"
		service["#{parts[0]}"]["request_path"] = "/api"
	end
	
end
service.each do |s,v|
	if v["site"] == s then
		puts " - found: #{v["name"]} [#{s}]"
	else
		puts " - error reading #{s}"
	end
end

# Registered services are stored in 'rubident'
puts "\nReading your account details... "
locals = File.open("#{ENV['HOME']}/.rubident", "r") { |f| f.read }	# auto-close
locals = locals.split("\n")
locals.each do |s|
	keys = s.split(" ")
	site = keys[0]
	service["#{site}"]["consumer_key"] = keys[1]
	service["#{site}"]["consumer_sec"] = keys[2]
	service["#{site}"]["registered"] = true
end

service.each do |s,v|
	if v["site"] == s && v["registered"] == true then
		puts " - found: #{v["name"]} [#{s}] => #{v["path"]}"
	elsif v["site"] == s && v["registered"] == false then
		puts " - (new): #{v["name"]} [#{s}] => #{v["path"]}"
	else
		puts " - error: #{v["name"]} [#{s}]"
	end
end


if ARGV[0] == "setup" then
	# Enter the base URL of the service, from which the API URL will be constructed
	# e.g. "twitter.com" not "api.twitter.com"
	print "\nURL of service: http://"
	site = STDIN.readline.chomp

	if site =~ /twitter/ then
		site = "#{service["https://api.twitter.com"]["site"]}"
	elsif site =~ /ident/ then
		site = "#{service["https://identi.ca"]["site"]}"
	end
	
	puts "Contacting #{service["#{site}"]["name"]} at #{service["#{site}"]["path"]}/authorize..."
	consumer = OAuth::Consumer.new(
		service["#{site}"]["key"],
		service["#{site}"]["secret"],
		:site               =>	"#{service["#{site}"]["site"]}",
		:authorize_path     =>  "#{service["#{site}"]["path"]}/authorize",
		:request_token_path	=>  "#{service["#{site}"]["path"]}/request_token",
		:access_token_path  =>  "#{service["#{site}"]["path"]}/access_token",
		:http_method        =>  :get
	)
	
	request_token = consumer.get_request_token
	
	puts "
To set-up rubident, open your web browser and sign in to #{service["#{site}"]["name"]}. Authorise rubident by visiting:
	#{request_token.authorize_url}

Enter the code: "
	pin = STDIN.readline.chomp
	
	access_token = request_token.get_access_token(:oauth_verifier => pin)
	
	file = File.new("#{ENV['HOME']}/.rubident", "a+")
	file.write("#{service["#{site}"]["site"]} #{access_token.token} #{access_token.secret}\n")
	file.close
	
else

	# How many available services are in 'rubident-keys' ?
	if service.length < 1
		puts "You don't have any services set up. Please create the 'rubident-keys' file."
	elsif service.length == 1
		puts "Using your default account."
		service = service.first
	else
		puts "\nSelect your service:"
		selection = []
		count = 1
		service.each do |s, v|
			puts " #{count}) #{v["name"]}"
			selection[count - 1] = v["site"]
			count += 1
		end
	choice = Integer(STDIN.readline.chomp)
	service = service["#{selection[choice - 1]}"]
	end

	# At this point we should have one service, default or selected
	puts "#{service["name"]} (#{service["site"]}) selected.\n"
	
	consumer = OAuth::Consumer.new(
		service["key"],
		service["secret"],
		:site               =>  site,
		:authorize_path     =>  "#{service["path"]}/authorize",
		:request_token_path	=>  "#{service["path"]}/request_token",
		:access_token_path  =>  "#{service["path"]}/access_token",
		:http_method        =>	:get
	)

	# Read and writes will be done through this access token
	access_token = OAuth::AccessToken.new(consumer, service["consumer_key"], service["consumer_sec"])

	case ARGV[0]
	when "post" then
		# Posting a message to the account
		url = "#{service["site"]}#{service["request_path"]}/account/verify_credentials.json"
		me = access_token.get(url)
		my = JSON.parse(me.body)
		coords = my["status"]["geo"].first.last ||= Array.new

		# Send the update
		update = access_token.post(
			"#{service["site"]}#{service["request_path"]}/statuses/update.json",
			"status" => ARGV[1],
			"lat"    => coords.first,
			"long"   => coords.last,
			"source" => "rubident"
		)
		# TODO: response !
		
	when "home" then
		url = "#{service["site"]}#{service["request_path"]}/statuses/home_timeline.json"
		data = access_token.get(url)
		json = JSON.parse(data.body)
		json.reverse.each do |p|
			puts "\n #{p["user"]["name"]} says:\n\t#{p["text"]}\n"
		end
	end
	
end
