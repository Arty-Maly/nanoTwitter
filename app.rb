require 'sinatra'
require 'sinatra/activerecord'
require './models/user'
require './models/tweet'
require './models/relationship'
require 'bcrypt'
require 'sinatra/flash'

enable :sessions

Tilt.register Tilt::ERBTemplate, 'html.erb'


#login helper 
helpers do
  
  def login?
    if session[:username].nil?
      return false
    else
      return true
    end
  end
  
  def username
    return session[:username]
  end
  
end

########################################

#routes

get '/' do 
	erb :login 
end

post "/login/" do
	handle = params[:username]
	user = User.where(handle: handle).first
  
    if user && user.password_hash == BCrypt::Engine.hash_secret(params[:password], user.password_salt)
      session[:username] = params[:username]
      redirect :main
    end
  
 flash[:alert] = "Problem. Please Try again."
end

# post '/login/' do
# 	handle = params[:username]
# 	user = User.where(handle: handle).first
	
# 	if user && user.password_hash] == BCrypt::Engine.hash_secret(params[:password], user.password_salt)
# 		session[:username] = params[:username]
#     	redirect :main
#     else 
#       	erb :error
#     end
# end

get "/signup" do
  erb :signup
end



post "/signup" do
	#make hash of parameters from html form and pass it to model
	hash = {:handle => params[:username]}
	hash[:password] = params[:password]
	user = User.new(hash)
	
  	if(user.save)
    	flash[:notice] = "Welcome to the App!"
      	redirect "/"
    	else
   		flash[:alert] = "Problem. Please Try again."
    end
  
  session[:username] = params[:username]
  erb :signup
end


get "/logout" do
  session[:username] = nil
  redirect "/"
end


get "/main" do 
	if login?
		#Creates a list(timeline) of all tweets made by a user's followers and the user themselves.
		@followee_tweets = []
		
		session_id = User.where(handle: session[:username]).first.id
		
		#Adds the logged-in user's own tweets to the list
		user_tweets = Tweet.order("id desc").where(user_id: session_id)
		user_tweets.each do |u_tweet|
			@followee_tweets.push(u_tweet)
		end
		
		#Adds followed users' tweets to the list
		followees = Relationship.where(follower_id: session_id).pluck(:followed_id)
		followees.each do |followee_id|
			f_tweets = Tweet.order("id desc").where(user_id: followee_id)
			f_tweets.each do |f_tweet|
				@followee_tweets.push(f_tweet)
			end
		end
		#Reorders the tweets so that the newest tweets are at the top.
		@followee_tweets.sort! { |tweet1,tweet2| tweet1.created_at <=> tweet2.created_at }
		@followee_tweets.reverse!
		
		#@num_followed and @num_following display number of followers/followees of the user, respectively
		@num_followers = Relationship.where(followed_id: session_id).length
		@num_following = Relationship.where(follower_id: session_id).length
		
		erb :main
	else
		erb :login
	end
end


post "/tweet" do
	user = User.where(handle: username).first
	tweet_text = params[:text]
	if tweet_text.length <= 140
		tweet = user.tweets.create(text: tweet_text)
	else
		flash[:alert] = "Please reduce the length of your tweet."
	end
	redirect "/main"
end


post "/tweet_search" do 

  puts params[:tweet_search]
	@search_results = Tweet.tweet_search(params[:tweet_search])

	erb :search
end


get "/look" do 
	#@does_follow is a boolean representing whether you are a follower or not.
	@does_follow = false
	profile_user_id = params[:userid].to_i
	if login?
		session_id = User.where(handle: session[:username]).first.id
		followees = Relationship.where(follower_id: session_id).pluck(:followed_id)
		followees.each do |followee|
			if followee == profile_user_id
				@does_follow = true
			end
		end
	end
	
	#@num_followers and @num_following display number of followers/followees of the profile owner
	@num_followers = Relationship.where(followed_id: profile_user_id).length
	@num_following = Relationship.where(follower_id: profile_user_id).length
	
	
  erb :look, :locals => {:userid => params[:userid]}
end 

post "/follow" do


  
  User.where(handle: session[:username]).first.follow(User.find(params[:userid]))
   
  flash[:notice] = "You are following " + User.find(params[:userid]).handle
  redirect "/look?userid=#{params[:userid]}"
  
end

post "/unfollow" do
	
	User.where(handle: session[:username]).first.unfollow(User.find(params[:userid]))
  
  flash[:notice] = "You are no longer following " + User.find(params[:userid]).handle
  redirect "/look?userid=#{params[:userid]}"
end

get "/followers" do
	follower_ids = Relationship.where(followed_id: params[:userid]).pluck(:follower_id)
	@followers = []
	follower_ids.each do |f_id|
		@followers.push(User.find(f_id))
	end
	erb :followers, :locals => {:userid => params[:userid]}
end

get "/followees" do
	followee_ids = Relationship.where(follower_id: params[:userid]).pluck(:followed_id)
	@followees = []
	followee_ids.each do |f_id|
		@followees.push(User.find(f_id))
	end
	erb :followees, :locals => {:userid => params[:userid]}
end

get "/users/profile" do
	if login?
		session_id = User.where(handle: session[:username]).first.id
		followee_ids = Relationship.where(follower_id: session_id).pluck(:followed_id)
		@followees = []
		followee_ids.each do |f_id|
			@followees.push(User.find(f_id))
		end
		erb :profile
	else
		erb :login
	end
end






























