#!/usr/bin/env ruby

%w{rubygems xmpp4r-simple}.each { |gem| require "#{gem}" }

credentials = Hash.new(  "useracct" => '',  "password" => '',  "instance" => ''  )

puts "Sent" if Jabber::Simple.new(credentials["useracct"], credentials["password"] ).deliver("update@" << credentials["instance"], ARGV[0])
