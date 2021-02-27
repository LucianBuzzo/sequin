require "../src/webserver"
require "crest"

describe WebServer do
  it "should respond to http requests" do
    server = WebServer.new

    puts "sending request"
    response = Crest.get("http://localhost:3000")

    response.body.should eq("Hello World!")
  end
end
