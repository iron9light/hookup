# -*- encoding: utf-8 -*-
require File.expand_path("../spec_helper", __FILE__)
# require "em-spec/rspec"


ClientSteps = EM::RSpec.async_steps do 

  def server(port, &callback)
    @server = TestServer.new
    @server.listen port
    @port = port
  ensure
    EM.add_timer(0.1, &callback)
  end

  def stop(&callback)
    @server.stop
    EM.next_tick(&callback)
  end

  def connect(url, retry_schedule = nil, &callback)
    done = false
    
    resume = lambda do |open|
      puts "resuming"
      unless done
        done = true
        callback.call
      end
    end
    
    @ws = Client.new(:uri => url, :reconnect_schedule => retry_schedule)
    
    @ws.on(:open) { 
      resume.call(true) }
    @ws.on(:close) { resume.call(false) }
    @ws.connect
  end

  def restart_server(&callback)
    @server.stop
    EM.add_timer(0.5) do  
      @ws.should_not be_connected  
      @server = TestServer.new
      @server.listen 8000
      EM.add_timer(0.1, &callback)
    end
  end

  def disconnect(&callback)
    @ws.on_disconnected do |e|
      callback.call
    end
    @ws.disconnect
  end

  def wait_for(seconds, &callback) 
    EM.add_timer(seconds) do
      callback.call
    end
  end
  
  def check_connected(&callback)
    puts "checking connected"
    @ws.should be_connected
    callback.call
  end
  
  def check_reconnected(&callback)
    @ws.should be_connected
    callback.call
  end
  
  def check_disconnected(&callback)
    @ws.should_not be_connected
    callback.call
  end

  def listen_for_message(&callback)
    @ws.on_receive { |e| @message = e.data }
    callback.call
  end
  
  def send_message(message, &callback)
    @ws.send(message)
    EM.add_timer(0.1, &callback)
  end
  
  def check_response(message, &callback)
    @message.should == message
    callback.call
  end

end

describe Backchat::Hookup::Client do
  # include ClientHelper
  # include EM::SpecHelper
  

  # default_timeout 1

  before do
    Thread.new { EM.run }
    sleep(0.1) until EM.reactor_running?
  end

  context "initializing" do

    before(:all) do
      @uri = "ws://localhost:2948/"
      @defaults_client = Client.new(:uri => @uri)
      @retries = 1..5
      @journaled = true
      @client = Client.new(:uri => @uri, :reconnect_schedule => @retries, :buffered => @journaled)
    end

    context "should raise when the uri param is" do
      it "missing" do
        (lambda do
          Client.new
        end).should raise_error(Backchat::Hookup::UriRequiredError)
      end

      it "an invalid uri" do 
        (lambda do
          Client.new :uri => "http:"
        end).should raise_error(Backchat::Hookup::InvalidURIError)
      end
    end

    it "should set use the default retry schedule" do
      @defaults_client.reconnect_schedule.should == Backchat::Hookup::RECONNECT_SCHEDULE
    end

    it "should set journaling as default to false" do
      @defaults_client.should_not be_buffered
    end

    it "should use the uri from the options" do
      @defaults_client.uri.should == @uri
    end

    it "should use the retry schedule from the options" do
      @client.reconnect_schedule.should == @retries
    end

    it "should use the journaling value from the options" do 
      @client.should be_buffered
    end
  end

  context "sending json to the server" do 



    # it "connects to the server" do
    #   em do
    #     server(8001)
    #     ws = Client.new("ws://127.0.0.1:8001/")
    #     op = false
    #     ws.on(:open) do 
    #       op = true
    #       ws.disconnect
    #     end
    #     ws.on(:close) do
    #       begin
    #         op.should be_true
    #         stop_server
    #       ensure
    #         done
    #       end
    #     end       
    #     ws.connect
    #   end
    # end

    # it "disconnects from the server" do
    #   em do
    #     server(8002)
    #     ws = Client.new("ws://127.0.0.1:8002/")
    #     ws.on(:open) do 
    #       ws.disconnect
    #     end
    #     ws.on(:close) do
    #       begin
    #         1.should == 1
    #         stop_server
    #       ensure
    #         done
    #       end
    #     end       
    #     ws.connect
    #   end
    # end

    # it "sends messages to the server" do
    #   msg = "I expect this to be echoed"
    #   em do
    #     server(8003)
    #     ws = Client.new("ws://127.0.0.1:8003/")
    #     ws.on(:open) do 
    #       ws.send msg
    #     end
    #     ws.on(:data) do |data|
    #       begin
    #         data.should == msg          
    #       ensure
    #         ws.disconnect
    #       end
    #     end
    #     ws.on(:close) do
    #       begin
    #         stop_server
    #       ensure
    #         done
    #       end
    #     end       
    #     ws.connect
    #   end
    # end

    # include ClientSteps

    # before { server 8000; connect("ws://0.0.0.0:8000/") }
    # after  { stop }

    # it "connects to the server" do
    #   check_connected
    #   disconnect
    # end

    # it "disconnects from the server" do
    #   disconnect
    #   check_disconnected
    # end

    # it "sends messages to the server" do
    #   listen_for_message
    #   send_message "I expect this to be echoed"
    #   check_response "I expect this to be echoed"
    # end

    # it "converts objects to json before sending" do 
    #   listen_for_message
    #   send_message ["subscribe", "me"]
    #   check_response ["subscribe", "me"].to_json
    # end

  end

  # context "fault-tolerance" do 

  #   include ServerClientSteps

  #   before { server 8000 }
  #   after  { sync ; stop }

  #   it "recovers if the server comes back within the schedule" do
  #     connect("ws://0.0.0.0:8000/", [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]) 
  #     restart_server
  #     wait_for(5)
  #     check_connected
  #   end

  #   # it "raises a Backchat::Minutes::ServerDisconnectedError if the server doesn't come back" do
  #   #   connect("ws://0.0.0.0:8000/", [1, 1, 1, 1, 1, 1, 1]) 
  #   #   stop
  #   #     check_disconnected
  #   #     EM.add_timer(3) { check_connected }
  #   #   end
  #   # end

  # end

end