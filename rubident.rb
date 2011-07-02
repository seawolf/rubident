#!/usr/bin/env ruby

%w{rubygems oauth json}.each { |gem| require "#{gem}" }

content = File.open("#{ENV['HOME']}/.rubident", "r") { |f| f.read }
keys = content.split(" ")

instance = keys[0]
oauth_consumer_key = keys[1]
oauth_consumer_sec = keys[2]

consumer = OAuth::Consumer.new(
	oauth_consumer_key,
	oauth_consumer_sec,
	:site 			=>	"http://" << instance,
	:authorize_path 	=>	"/api/oauth/authorize",
	:request_token_path 	=>	"/api/oauth/request_token",
	:access_token_path 	=>	"/api/oauth/access_token",
	:http_method 		=>	:get
)

# No Access Token needed:
# access_token = OAuth::AccessToken.new consumer
# access_token.get("/api/statuses/public_timeline.xml")
# pp access_token

# New Access Token:
# request_token = consumer.get_request_token
# puts "Place #{request_token.authorize_url} in your browser"
# print "Enter the number displayed: "
# pin = STDIN.readline.chomp
# access_token = request_token.get_access_token(:oauth_verifier => pin)

access_token = OAuth::AccessToken.new(consumer, keys[3], keys[4])
me = access_token.get("/api/statuses/user_timeline.json")
my = JSON.parse(me.body)
coords = my.first["geo"].first.last

case ARGV[0]
	when "setup" then
		puts "I haven't written this bit yet."

	when "post" then
		update = access_token.post(
			"/api/statuses/update.json",
			"status" => ARGV[1],
			"source" => "rubident",
			"lat" => coords.first,
			"long" => coords.last )

	when "home" then
		 url = "/api/statuses/home_timeline.json"
		data = access_token.get(url)
		json = JSON.parse(data.body)
		json.each do |p|
			puts "\n #{p["user"]["name"]} says:\n\t#{p["text"]}\n" 
		end
		json.size

	else
		puts "Hello."
end
