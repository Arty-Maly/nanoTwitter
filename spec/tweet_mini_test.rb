require 'minitest/autorun'
require 'rack/test'
require File.expand_path(File.join(File.dirname(__FILE__), "../app.rb"))
set :environment, :test

describe "follow" do
	include Rack::Test::Methods
	
 	def app
 		Sinatra::Application
 	end

   	before(:each) do
   		User.delete_all
 		Tweet.delete_all
   		#Creates a user
   		user_hash1 = {:handle => "bill", :password => "test1"}
 		User.create(user_hash1)
		@bill = User.where(handle: "bill").first
		@bill_id = @bill.id
   	end

 	#Unit tests on tweet functionality
 	describe "tweet" do
 		describe "creates a tweet" do
 			it "creates a database entry" do
 				text = Faker::Hacker.say_something_smart
 				Tweet.create(user_id: @bill_id, text: text)
 				Tweet.where(user_id: @bill_id, text: text).first.nil?.must_equal false
 			end
 			it "identifies the correct id for the user who tweeted" do
 				tweet = Tweet.create(user_id: @bill_id, text: "")
 				@bill_id.must_equal tweet.user_id
 			end
 		end
 		it "deletes an entry in the tweet table" do
 			Tweet.create(user_id: @bill_id, text: "")
 			Tweet.where(user_id: @bill_id, text: "").first.destroy
 			Tweet.where(user_id: @bill_id, text: "").first.must_equal nil
 		end
 	end
	
 	#Tests the User#tweet method
 	describe "user" do		
 		it "creates a tweet" do
 			text = Faker::Hacker.say_something_smart
 			@bill.tweet(text)
 			Tweet.where(user_id: @bill_id, text: text).first.nil?.must_equal false
 		end
 		it "identifies the correct id for the user who tweeted" do
 			tweet = @bill.tweet("")
 			User.find(tweet.user_id).must_equal @bill
 		end
 	end
	
	#Tests the Tweet.search_latest_tweets(text) and Tweet.search_latest_tweets_by_users(user_ids) methods
	describe "tweet" do
		before do
			@phil = User.create({:handle => "phil", :password => "test2"})
 			@paul = User.create({:handle => "paul", :password => "test3"})
			(1..33).each do |num|
				@bill.tweet("bill"+num.to_s)
			end
			(1..33).each do |num|
				@phil.tweet("phil"+num.to_s)
			end
			(1..33).each do |num|
				@paul.tweet("paul"+num.to_s)
			end
			(1..2).each do |num|
				@bill.tweet("2bill"+num.to_s)
			end
		end

		it "returns the latest tweets with a given text in it" do
			results = Tweet.search_latest_tweets("bill")
			results.count.must_equal 35
			results[0].text.must_equal "2bill2"
			results[30].text.must_equal "bill5"
		end

		it "returns the latest tweets by a given set of user ids" do
			results = Tweet.search_latest_tweets_by_users([@paul.id, @phil.id])
			results.count.must_equal 66
			results[0].text.must_equal "paul33"
			results[33].text.must_equal "phil33"
		end
	end

 	#Integration tests on tweet functionality
    describe "http methods" do
 		before(:each) do
 		end
 		describe "POST on /tweet_search" do
 			it "should display the latest tweets with a given text in them" do
 				text = "Hello " + Time.now.to_s
 				text2 = "Hello 2"
 				text3 = "Hello 3"
 				@bill.tweet(text)
 				@bill.tweet(text2)
 				@bill.tweet(text3)

 				post "/tweet_search", {:tweet_search => "Hello"}
 				last_response.must_be :ok?
 				last_response.body.must_include text
 				last_response.body.must_include text2
 				last_response.body.must_include text3
 			end

 			it "should not display the latest tweets that do not have the given text" do
 				text = "Hello " + Time.now.to_s
 				@bill.tweet(text)

 				post "/tweet_search", {:tweet_search => "Goodbye"}
 				last_response.must_be :ok?
 				last_response.body.wont_include text
 			end
 		end
 		describe "POST on /tweet" do
 			it "should create a tweet object" do
 				text = "Goodbye " + Time.now.to_s
 				post "/tweet", {:text => text}, { "rack.session" => {:userid => @bill_id, :username => "bill"}}
 				Tweet.where(text: text).first.nil?.must_equal false
 			end
 		end
 	end
end

REDIS.flushdb