require 'minitest/autorun'
require 'rack/test'
require_relative '../app.rb'
set :environment, :test

describe "follow" do
	include Rack::Test::Methods
	
	def app
		Sinatra::Application
	end
	
  before do
    User.delete_all
	Relationship.delete_all
	Tweet.delete_all
  end
	
	#Unit tests on follow functionality
	describe "follow" do
		before(:each) do
			user_hash1 = {:handle => "bill", :password => "test1"}
			User.create(user_hash1)
			user_hash2 = {:handle => "phil", :password => "test2"}
			User.create(user_hash2)
			
			@bill_id = User.where(handle: "bill").first.id
			@phil_id = User.where(handle: "phil").first.id
		end
		describe "creates a relationship" do
			it "creates a database entry" do
				Relationship.create(follower_id: @bill_id, followed_id: @phil_id)
				Relationship.where(follower_id: @bill_id, followed_id: @phil_id).first.nil?.must_equal false
			end
			it "identifies the correct id for follower" do
				Relationship.create(follower_id: @bill_id, followed_id: @phil_id)
				follower_id = Relationship.where(follower_id: @bill_id, followed_id: @phil_id).first.follower_id
				User.find(follower_id).id.must_equal @bill_id
			end
			it "identifies the correct id for followed user" do
				Relationship.create(follower_id: @bill_id, followed_id: @phil_id)
				followed_id = Relationship.where(follower_id: @bill_id, followed_id: @phil_id).first.followed_id
				User.find(followed_id).id.must_equal @phil_id
			end
		end
		it "deletes a database entry" do
			Relationship.create(follower_id: @bill_id, followed_id: @phil_id)
			Relationship.where(follower_id: @bill_id, followed_id: @phil_id).first.destroy
			Relationship.where(follower_id: @bill_id, followed_id: @phil_id).first.must_equal nil
		end
	end
	
	#Tests the User.follow and User.unfollow methods
	describe "user" do
		before(:each) do
			user_hash1 = {:handle => "bill", :password => "test1"}
			User.create(user_hash1)
			user_hash2 = {:handle => "phil", :password => "test2"}
			User.create(user_hash2)
			
			@bill = User.where(handle: "bill").first
			@phil = User.where(handle: "phil").first
		end
		
		it "follows a user" do
			@bill.follow(@phil)
			Relationship.where(follower_id: @bill.id, followed_id: @phil.id).first.nil?.must_equal false
		end
		
		it "unfollows a user" do
			@bill.follow(@phil)
			@bill.unfollow(@phil)
			Relationship.where(follower_id: @bill.id, followed_id: @phil.id).first.must_equal nil
		end
	end
	
	#Integration tests on follow functionality
  describe "http methods" do
		before(:each) do
			user_hash1 = {:handle => "bill", :password => "test1"}
			User.create(user_hash1)
			user_hash2 = {:handle => "phil", :password => "test2"}
			User.create(user_hash2)
			user_hash3 = {:handle => "paul", :password => "test3"}
			User.create(user_hash3)
	
			@bill = User.where(handle: "bill").first
			@phil = User.where(handle: "phil").first
			@paul = User.where(handle: "paul").first
		end
		
		describe "POST on /follow" do
			it "should create a follow relationship from logged-in user to given user" do
				post '/follow', {:userid => @phil.id}, { "rack.session" => {:username => "bill",:userid => @bill.id}}
				Relationship.where(follower_id: @bill.id, followed_id: @phil.id).first.nil?.must_equal false
			end
		end
	
		describe "POST on /unfollow" do
			it "should delete a follow relationship" do
				Relationship.create(follower_id: @bill.id, followed_id: @phil.id)
				post '/unfollow', {:userid => @phil.id}, { "rack.session" => {:username => "bill",:userid => @bill.id}}
				Relationship.where(follower_id: @bill.id, followed_id: @phil.id).first.must_equal nil
			end
		end
		
		describe "GET on /followers" do
			it "should return a user's followers" do
				Relationship.create(follower_id: @bill.id, followed_id: @phil.id)
				Relationship.create(follower_id: @paul.id, followed_id: @phil.id)
				get '/followers', :userid => @phil.id
				last_response.must_be :ok?
				last_response.body.must_include "paul"
				last_response.body.must_include "bill"
				last_response.body.wont_include "carl"
			end
		end
		
		describe "GET on /followees" do
			it "should return a user's followees" do
				Relationship.create(follower_id: @phil.id, followed_id: @paul.id)
				Relationship.create(follower_id: @phil.id, followed_id: @bill.id)
				get '/followees', :userid => @phil.id
				last_response.must_be :ok?
				last_response.body.must_include "paul"
				last_response.body.must_include "bill"
				last_response.body.wont_include "carl"
			end
		end
		
		describe "GET on /user" do
			it "should display the correct number of followers" do
				Relationship.create(follower_id: @bill.id, followed_id: @phil.id)
				get "/user/#{@phil.id}", {:userid => @phil.id}, { "rack.session" => {:username => "bill"}}
				last_response.must_be :ok?
				last_response.body.must_include "Followers: 1 Users"
				
				get "/user/#{@bill.id}", {:userid => @bill.id}, { "rack.session" => {:username => "phil"}}
				last_response.must_be :ok?
				last_response.body.must_include "Followers: 0 Users"
			end
			
			it "should display the correct number of users being followed" do
				Relationship.create(follower_id: @bill.id, followed_id: @phil.id)
				get "/user/#{@bill.id}", {:userid => @bill.id}, { "rack.session" => {:username => "phil"}}
				last_response.must_be :ok?
				last_response.body.must_include "Following: 1 Users"
				
				get "/user/#{@phil.id}", {:userid => @phil.id}, { "rack.session" => {:username => "bill"}}
				last_response.must_be :ok?
				last_response.body.must_include "Following: 0 Users"
			end
			
			it "should display a follow button if the logged-in user is not a follower" do
				get "/user/#{@phil.id}", {:userid => @phil.id}, { "rack.session" => {:username => "bill"}}
				last_response.must_be :ok?
				last_response.body.wont_include "form action='/unfollow'"
				last_response.body.must_include "form action='/follow'"
			end
			
			it "should display an unfollow button if the logged-in user is a follower" do
				Relationship.create(follower_id: @bill.id, followed_id: @phil.id)
				get "/user/#{@phil.id}", {:userid => @phil.id}, { "rack.session" => {:username => "bill"}}
				last_response.must_be :ok?
				last_response.body.wont_include "form action='/follow'"
				last_response.body.must_include "form action='/unfollow'"
			end

			it "should display no follow or unfollow button if the user is not logged in" do
				get "/user/#{@phil.id}", :userid => @phil.id
				last_response.must_be :ok?
				last_response.body.wont_include "form action='/follow'"
				last_response.body.wont_include "form action='/unfollow'"
			end
		end
	end
end