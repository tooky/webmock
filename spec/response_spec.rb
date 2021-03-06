require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ResponseFactory do

  describe "response_for" do

    it "should create response with options passed as arguments" do
      options = {:body => "abc", :headers => {:a => :b}}
      Response.should_receive(:new).with(options).and_return(@response = mock(Response))
      ResponseFactory.response_for(options).should == @response
    end


    it "should create dynamic response for argument responding to call" do
      callable = mock(:call => {:body => "abc"})
      DynamicResponse.should_receive(:new).with(callable).and_return(@response = mock(Response))
      ResponseFactory.response_for(callable).should == @response
    end

  end

end

describe Response do
  before(:each) do
    @response = Response.new(:headers => {'A' => 'a'})
  end

  it "should report normalized headers" do
    Util::Headers.should_receive(:normalize_headers).with('A' => 'a').and_return('B' => 'b')
    @response = Response.new(:headers => {'A' => 'a'})
    @response.headers.should == {'B' => 'b'}
  end

  describe "status" do

    it "should have 200 code and empty message by default" do
      @response.status.should == [200, ""]
    end

    it "should return assigned status" do
      @response = Response.new(:status => 500)
      @response.status.should == [500, ""]
    end

    it "should return assigned message" do
      @response = Response.new(:status => [500, "Internal Server Error"])
      @response.status.should == [500, "Internal Server Error"]
    end

  end

  describe "raising error" do

    it "should raise error if any assigned" do
      @response = Response.new(:exception => ArgumentError)
      lambda {
        @response.raise_error_if_any
      }.should raise_error(ArgumentError, "Exception from WebMock")
    end

    it "should not raise error if no error assigned" do
      @response.raise_error_if_any
    end

  end
  
  describe "timeout" do

    it "should know if it should timeout" do
      @response = Response.new(:should_timeout => true)
      @response.should_timeout.should be_true
    end

    it "should not timeout by default" do
      @response = Response.new
      @response.should_timeout.should be_false
    end

  end

  describe "body" do

    it "should return empty body by default" do
      @response.body.should == ''
    end

    it "should report body if assigned" do
      @response = Response.new(:body => "abc")
      @response.body.should == "abc"
    end

    it "should report string even if existing file path was provided" do
      @response = Response.new(:body => __FILE__)
      @response.body.should == __FILE__
    end

    it "should report content of a IO object if provided" do
      @response = Response.new(:body => File.new(__FILE__))
      @response.body.should == File.new(__FILE__).read
    end

    it "should report many times content of a IO object if provided" do
      @response = Response.new(:body => File.new(__FILE__))
      @response.body.should == File.new(__FILE__).read
      @response.body.should == File.new(__FILE__).read
    end

  end

  describe "from raw response" do

    describe "when input is IO" do
      before(:each) do
        @file = File.new(File.expand_path(File.dirname(__FILE__)) + "/example_curl_output.txt")
        @response = Response.new(@file)
      end


      it "should read status" do
        @response.status.should == [202, "OK"]
      end

      it "should read headers" do
        @response.headers.should == {
          "Date"=>"Sat, 23 Jan 2010 01:01:05 GMT",
          "Content-Type"=>"text/html; charset=UTF-8",
          "Content-Length"=>"438",
          "Connection"=>"Keep-Alive",
          "Accept"=>"image/jpeg, image/png"
          }
      end

      it "should read body" do
        @response.body.size.should == 438
      end

      it "should close IO" do
        @file.should be_closed
      end

    end

    describe "when input is String" do
      before(:each) do
        @input = File.new(File.expand_path(File.dirname(__FILE__)) + "/example_curl_output.txt").read
        @response = Response.new(@input)
      end

      it "should read status" do
        @response.status.should == [202, "OK"]
      end

      it "should read headers" do
        @response.headers.should == {
          "Date"=>"Sat, 23 Jan 2010 01:01:05 GMT",
          "Content-Type"=>"text/html; charset=UTF-8",
          "Content-Length"=>"438",
          "Connection"=>"Keep-Alive",          
          "Accept"=>"image/jpeg, image/png"
          }
      end

      it "should read body" do
        @response.body.size.should == 438
      end

      it "should work with transfer-encoding set to chunked" do
        @input.gsub!("Content-Length: 438", "Transfer-Encoding: chunked")
        @response = Response.new(@input)
        @response.body.size.should == 438
      end

    end

    describe "with dynamically evaluated options" do

      before(:each) do
        @request_signature = RequestSignature.new(:post, "www.example.com", :body => "abc", :headers => {'A' => 'a'})
      end

      it "should have evaluated body" do
        @response = Response.new(:body => lambda {|request| request.body})
        @response.evaluate!(@request_signature).body.should == "abc"
      end

      it "should have evaluated headers" do
        @response = Response.new(:headers => lambda {|request| request.headers})
        @response.evaluate!(@request_signature).headers.should == {'A' => 'a'}
      end

      it "should have evaluated status" do
        @response = Response.new(:status => lambda {|request| 302})
        @response.evaluate!(@request_signature).status.should == [302, ""]
      end

    end

  end

  describe DynamicResponse do

    describe "evaluating response options" do

      it "should have evaluated options" do
        request_signature = RequestSignature.new(:post, "www.example.com", :body => "abc", :headers => {'A' => 'a'})
        response = DynamicResponse.new(lambda {|request|
          {
            :body => request.body,
            :headers => request.headers,
            :status => 302
          }
        })
        response.evaluate!(request_signature)
        response.body.should == "abc"
        response.headers.should == {'A' => 'a'}
        response.status.should == [302, ""]
      end

      it "should be equal to static response after evaluation" do
        request_signature = RequestSignature.new(:post, "www.example.com", :body => "abc")
        response = DynamicResponse.new(lambda {|request| {:body => request.body}})
        response.evaluate!(request_signature)
        response.should == Response.new(:body => "abc")
      end

    end

  end

end
