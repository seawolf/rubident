load 'rubident.rb'

describe "at startup, the application" do

  before :each do
    # Initialise an instance
    @client = Rubident.new("silent")
  end
  
  it "should create a client to work with" do
    @client.should_not be_nil
    @client.class.should.eql? Rubident
  end
  
  pending "should quit gracefully if required files cannot be found" do
    File.open("VERSION", "r").should 
    @client.check_for_files
  end

  it "should have a version number" do
    @client.version.should_not be_nil
    @client.version.length.should > 0
  end
    
  it "should load at least some of the required gems" do
    # Ensure JSON is available to parse data
    ['to_json'].to_json.should_not be_nil
    ['to_json'].to_json.should_not be_empty
  end
  
  it "should read a file of supported services" do
    @client.services.should_not be_nil
  end
  
  pending "should understand accountlessness" # do
  # end
  
  it "should understand accounts" do
    #
  end
  
end
=begin
describe "setting up an account" do
  
  pending "set up an account on the twitter service" # do
  # end
  
  pending "set up a different account on the twitter service" # do
  # end
  
  pending "set up an account on the identi.ca service" # do
  # end
  
  pending "set up a different account on the identi.ca service" # do
  # end
  
end

describe "viewing timelines" do
  
  pending "view the home timeline for an account" # do
  # end
  
  pending "view the replies to an account" # do
  # end
  
  pending "view the direct messages sent to an account" # do
  # end
  
  pending "view the direct messages sent by an account" # do
  # end
  
  pending "check whether a service has a public stream" # do
  # end
  
  pending "view the public stream for a service" # do
  # end
  
end

describe "posting messages" do
  
  pending "post a message from an account" # do
  # end
  
  pending "post a direct message from an account" # do
  # end
=end
