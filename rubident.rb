#!/usr/bin/env ruby
%w{rubygems bundler/setup oauth json}.each { |gem| require "#{gem}" }
%w{helpers}.each { |file| load "#{file}.rb" }

class Rubident
  attr_accessor :version, :services

  def initialize(silent = false)
    begin
      self.version = File.open("VERSION", "r") { |f| f.read }
    rescue Errno::ENOENT
      abort "\nNo version file found. Your installation of rubident may be broken."
    end
    puts "Rubident v.#{self.version}\n\n" unless silent

    # All available services will reside in:
    self.services = Hash.new
  
    %w{sites accounts}.each do |f|
      begin
        # Try to open existing file
        file = File.open("#{ENV["HOME"]}/.config/rubident/#{f}", "r")
        file.close
      rescue # Dir or File not found
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
    puts "Reading supported services... " unless silent
    globals = File.open("#{ENV['HOME']}/.config/rubident/sites", "r") { |f| f.read } # auto-close
    globals = globals.split("\n")
    globals.each do |line|
      parts = line.split(" ")
      self.services["#{parts[0]}"] = {
        "site"         => "#{parts[0]}",
        "key"          => "#{parts[1]}",
        "secret"       => "#{parts[2]}",
        "name"         => "#{parts[3]}",
        "registered"   => false
      }

      # While the API may be compatible, each service may differ
      if parts[0] =~ /twitter/
        self.services["#{parts[0]}"]["path"] = "/oauth"
        self.services["#{parts[0]}"]["request_path"] = "/1"
      elsif parts[0] =~ /identi/
        self.services["#{parts[0]}"]["path"] = "/api/oauth"
        self.services["#{parts[0]}"]["request_path"] = "/api"
      end
    end
  
    self.services.each do |s,v|
      if v["site"] == s then
        puts " - found: #{v["name"]} [#{s}]" unless silent
      else
        puts " - error reading #{s}" unless silent
      end
    end

    # Registered services are stored in 'rubident'
    puts "\nReading your account details... " unless silent
    locals = File.open("#{ENV['HOME']}/.config/rubident/accounts", "r") { |f| f.read } # auto-close
    locals = locals.split("\n")
    locals.each do |s|
      keys = s.split(" ")
      site = keys[0]
      self.services["#{site}"]["consumer_key"] = keys[1]
      self.services["#{site}"]["consumer_sec"] = keys[2]
      self.services["#{site}"]["registered"] = true
    end

    self.services.each do |s,v|
      if v["site"] == s && v["registered"] == true then
        puts " - found: #{v["name"]} [#{s}] => #{v["path"]}" unless silent
      elsif v["site"] == s && v["registered"] == false then
        puts " - (new): #{v["name"]} [#{s}] => #{v["path"]}" unless silent
      else
        puts " - error: #{v["name"]} [#{s}]"
      end
    end

    return self.services
  end

  def setup
    # Enter the base URL of the service, from which the API URL will be constructed
    # e.g. "twitter.com" not "api.twitter.com"
    print "\nURL of service: http://"
  
    site = STDIN.readline.chomp
        if site =~ /twitter/
      site = "#{self.services["https://api.twitter.com"]["site"]}"
    elsif site =~ /ident/
      site = "#{self.services["https://identi.ca"]["site"]}"
    else
      puts "#{site} is not recognised. Contact the developers if you would like to request support for this service."
      exit 0
    end
  
    puts "Contacting #{self.services["#{site}"]["name"]} at #{self.services["#{site}"]["path"]}/authorize..."
    consumer = OAuth::Consumer.new(
      self.services["#{site}"]["key"],
      self.services["#{site}"]["secret"],
      :site               =>  "#{self.services["#{site}"]["site"]}",
      :authorize_path     =>  "#{self.services["#{site}"]["path"]}/authorize",
      :request_token_path  =>  "#{self.services["#{site}"]["path"]}/request_token",
      :access_token_path  =>  "#{self.services["#{site}"]["path"]}/access_token",
      :http_method        =>  :get
    )
  
    request_token = consumer.get_request_token
  
    print "
  To set-up rubident, open your web browser and sign in to #{self.services["#{site}"]["name"]}. Authorise rubident by visiting:
    #{request_token.authorize_url}

  Enter the code: "
    pin = STDIN.readline.chomp
  
    @access_token = request_token.get_access_token(:oauth_verifier => pin)
  
    file = File.new("#{ENV['HOME']}/.config/rubident/accounts", "a+")
    file.write("#{self.services["#{site}"]["site"]} #{@access_token.token} #{@access_token.secret}\n")
    file.close
  end

  def select_service
    # How many available services are in 'rubident-keys' ?
    if self.services.length < 1
      puts "You don't have any services set up. Please create the 'rubident-keys' file."
    elsif self.services.length == 1
      puts "Using your default account."
      self.services = self.services.first
    else
      puts "\nSelect your service:"
      selection = []
      count = 1
      self.services.each do |s, v|
        puts " #{count}) #{v["name"]}"
        selection[count - 1] = v["site"]
        count += 1
      end
    choice = Integer(STDIN.readline.chomp)
    self.services = self.services["#{selection[choice - 1]}"]
    end

    # At this point we should have one service, default or selected
    puts "#{self.services["name"]} (#{self.services["site"]}) selected.\n"
  
    consumer = OAuth::Consumer.new(
      self.services["key"],
      self.services["secret"],
      :site               =>  "#{self.services["site"]}",
      :authorize_path     =>  "#{self.services["path"]}/authorize",
      :request_token_path  =>  "#{self.services["path"]}/request_token",
      :access_token_path  =>  "#{self.services["path"]}/access_token",
      :http_method        =>  :get
    )

    # Read and writes will be done through this access token
    @access_token = OAuth::AccessToken.new(consumer, self.services["consumer_key"], self.services["consumer_sec"])

    return self.services
  end

  def post
    # Posting a message to the account
    print "\nEnter your message: "
    message = STDIN.readline.chomp
  
    # Prepare extra submission data
    url = "#{self.services["site"]}#{self.services["request_path"]}/account/verify_credentials.json"
    me = @access_token.get(url)
    my = JSON.parse(me.body)
    coords = my["status"]["geo"]["coordinates"] ||= Array.new("","")

    # Send the update
    update = @access_token.post(
      "#{self.services["site"]}#{self.services["request_path"]}/statuses/update.json",
      "status" => message,
      "lat"    => coords.first,
      "long"   => coords.last,
      "source" => "rubident"
    ).body
  
    # TODO: response !
  end

  def post_dm
    # Posting private/direct message to an account
    print "\nEnter the recipient: @"
    user = STDIN.readline.chomp
  
    print "\nEnter your message: "
    message = STDIN.readline.chomp
  
    # Prepare extra submission data
    url = "#{self.services["site"]}#{self.services["request_path"]}/account/verify_credentials.json"
    me = @access_token.get(url)
    my = JSON.parse(me.body)
    coords = my["status"]["geo"].first.last ||= Array.new
  
    # Send the update
    update = @access_token.post(
      "#{self.services["site"]}#{self.services["request_path"]}/direct_messages/new.json",
      "screen_name" => user,
      "text"         => message
    ).body
  
    # TODO: response !
  end

  def home
    url = "#{self.services["site"]}#{self.services["request_path"]}/statuses/home_timeline.json"
    data = @access_token.get(url)
    json = JSON.parse(data.body)
    json.reverse.each do |p|
      puts "\n #{p["user"]["name"]} (@#{p["user"]["screen_name"]}) said #{Helpers.format_timestamp p["created_at"]}:\n\t#{p["text"]}\n"
    end
  end

  def replies
    url = "#{self.services["site"]}#{self.services["request_path"]}/statuses/replies.json"
    data = @access_token.get(url)
    json = JSON.parse(data.body)
    json.reverse.each do |p|
      puts "\n #{p["user"]["name"]} says:\n\t#{p["text"]}\n"
    end
  end

  def inbox
    url = "#{self.services["site"]}#{self.services["request_path"]}/direct_messages.json"
    data = @access_token.get(url)
    json = JSON.parse(data.body)
    json.reverse.each do |p|
      puts "\n #{p["sender"]["name"]} (@#{p["sender"]["screen_name"]}) said #{Helpers.format_timestamp p["created_at"]}:\n\t#{p["text"]}\n"
    end
  end

  def outbox
    url = "#{self.services["site"]}#{self.services["request_path"]}/direct_messages/sent.json"
    data = @access_token.get(url)
    json = JSON.parse(data.body)
    json.reverse.each do |p|
      puts "\n You said to #{p["sender"]["name"]} (@#{p["sender"]["screen_name"]}):\n\t#{p["text"]}\n"
    end
  end

  def public
    url = "#{self.services["site"]}#{self.services["request_path"]}/statuses/public_timeline.json"
    data = @access_token.get(url)
    json = JSON.parse(data.body)
    json.reverse.each do |p|
      puts "\n #{p["user"]["name"]} (@#{p["user"]["screen_name"]}) said #{Helpers.format_timestamp p["created_at"]}:\n\t#{p["text"]}\n"
    end
  end

end

if $0.include? "rubident.rb"
  client = Rubident.new
  if         ARGV[0] == "setup"     then client.setup
  else      client.select_service
    if       ARGV[0] == "post"     then client.post
    elsif   ARGV[0] == "dm"       then client.post_dm
    elsif   ARGV[0] == "home"     then client.home
    elsif   ARGV[0] == "replies"  then client.replies
    elsif   ARGV[0] == "inbox"    then client.replies
    elsif   ARGV[0] == "outbox"    then client.replies
    elsif   ARGV[0] == "public"    then client.public
    elsif    ARGV[0]                then puts "
To use rubident, you must use one of the following as the first command:
  setup   -  associate a service and account
  home    -  your timeline
  post    -  send a message
  inbox   -  your private messages
  dm      -  send a private message
  outbox  -  sent private messages
  public  -  most recently-posted messages from everyone*
  
  * - selected services only
  
e.g.
  ./rubident.rb home"
    end
  end
end
