require 'sinatra'
require 'sinatra/activerecord'
require './models/user'
require './models/tweet'
require './models/relationship'
require 'bcrypt'
require 'sinatra/flash'
require "./config/redis"
require 'json'
enable :sessions

Tilt.register Tilt::ERBTemplate, 'html.erb'
	
		#Dont touch this for now. >>>>>>>>>>>>>>>>
		#probs should go into a helper method
		#on initialize flush redis db and recreate top 100 latest tweets
		REDIS.flushdb
		@global = Tweet.search_latest_tweets("")
		@global.each do |tweet|
			hash = Hash.new
			hash[:user_id] = tweet.user_id
			hash[:handle] = tweet.handle
			hash[:text] = tweet.text
			hash[:created_at] = tweet.created_at

			REDIS.lpush("latest100", hash.to_json)
		end
	#<<<<<<<<<<<<<<<<<<<<<<<<<<<

#helper methods for the rest of the code 
helpers do
  
	#Checks if the computer user is logged in
  def login?
    if session[:username].nil?
      return false
    else
      return true
    end
  end
  
	#Returns the username of the current logged-in user
  def username
    return session[:username]
  end
	
	#Redirects to the logged-in user's personal page
	def go_to_profile
		if login?
			session_id = User.where(handle: session[:username]).first.id
			#Queries the database for the handle and id of all users that are followed by the session user by 
			#performing a join between the relationships and users tables.
			@followees = Relationship.find_by_sql("SELECT users.handle, users.id FROM relationships 
				INNER JOIN users ON relationships.followed_id = users.id
				WHERE relationships.follower_id = #{session_id}
				ORDER BY relationships.created_at desc
				")
			erb :profile
		else
			erb :login
		end
	end
#constructing the redis list for a user top 100 tweets of who he follows
	def redis_list_for_user(user, timeline_ids)
		
		#Retrieves the last 100 followees' tweets, ordered from most recent to oldest
		followee_tweets = Tweet.find_by_sql("
			SELECT tweets.text, tweets.user_id, tweets.created_at, users.handle FROM tweets
			INNER JOIN users ON tweets.user_id = users.id
			WHERE tweets.user_id IN (#{timeline_ids})
			ORDER BY tweets.created_at desc
			LIMIT 100
			")
		followee_tweets.each do |tweet|
			hash = Hash.new
			hash[:user_id] = followee_tweets.user_id
			hash[:handle] = followee_tweets.handle
			hash[:text] = followee_tweets.text
			hash[:created_at] = followee_tweets.created_at
			REDIS.lpush(user, hash.to_json)
		end
		REDIS.expire(user, 120)
	end
#list of tweets from a user
	def redis_personal_list_for_user(user, profile_user_id)
		tweets = Tweet.find_by_sql("SELECT tweets.text, tweets.created_at FROM tweets
			WHERE tweets.user_id = #{profile_user_id}
			ORDER BY created_at DESC
			LIMIT 100")
		tweets.each do |tweet|
			hash = Hash.new
			hash[:text] = tweet.text
			hash[:created_at] = tweet.created_at
			REDIS.lpush(user, hash.to_json)
		end
		REDIS.expire(user, 120)

	end
  
end

########################################

#routes

#Loader authentication token
get '/loaderio-cb42c0b1ba46fc44b724647ec508a058/' do 
	"loaderio-cb42c0b1ba46fc44b724647ec508a058"
end

#other loader token

get '/loaderio-5f5ecc0ac53eec6834d377dbb3605118/' do 
	"loaderio-5f5ecc0ac53eec6834d377dbb3605118"
end

############################################################################################################################################
#Get method for the main page
get "/" do 
	#Returns a list of tweets from all users in descending order
	@global_tweets = Tweet.search_latest_tweets("")

	if login?
		#timeline_ids is a list of the ids of a user's followers and the user themselves.
		#Rather than a ruby list, this is a concatenated string, in order to mimic SQL syntax
		
		#Adds the user's id
		@session_id = User.where(handle: session[:username]).first.id
		timeline_ids = @session_id.to_s
		
		#Adds followed users' ids to the list
		followees_relationships = Relationship.where(follower_id: @session_id)
		followees = followees_relationships.pluck(:followed_id)
		followees.each do |followee|
			timeline_ids = "#{timeline_ids} , #{followee.to_s}"
		end
		
		
		if REDIS.exists(session[:username]) == false
			redis_list_for_user(session[:username], timeline_ids)
		end
		
				
		
		#@num_followed and @num_following display number of followers/followees of the user, respectively
		@num_followers = Relationship.count_followers(@session_id)
		@num_following = followees_relationships.length
		
		erb :main
	else
		erb :login
	end
end

#Post method for a login action
post "/login" do
	handle = params[:username]
	user = User.where(handle: handle).first

  
	if user && user.password_hash == BCrypt::Engine.hash_secret(params[:password], user.password_salt)
		session[:username] = handle
		session[:id] = user.id
		redirect "/"
	end
  
	flash[:alert] = "Problem. Please Try again."
end

#Get method for signing up with a new account. Directs to the signup view.
get "/user/register" do
  erb :signup
end

#Post method for registering a new account. Adds a new user based on inputter values.
post "/user/register" do
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

#Get method for the logout page
get "/logout" do
  session[:username] = nil
  redirect "/"
end

#Post method for tweets. Checks if a submitted text is 140 characters or less. If it is, then it is 
#used to create a tweet.
post "/tweet" do
	user = User.where(handle: username).first
	tweet_text = params[:text]
	if tweet_text.length <= 140
		tweet = user.tweets.create(text: tweet_text)
	else
		flash[:alert] = "Please reduce the length of your tweet."
	end
	redirect "/"
end

#Searches for tweets based on an inputted string. Redirects to a search result page with every tweet
#that has that string as part of its text.
post "/tweet_search" do 
	@search_results = Tweet.search_latest_tweets(params[:tweet_search])
	erb :search
end

#A get method for individual user pages. Each user's page corresponds to their user id.
get "/user/:userid" do 
	#If the uri is /user/profile, then the browser redirects to a personal profile page for the logged
	#in user
	if params[:userid] == "profile"
		go_to_profile
	else
		#@does_follow is a boolean representing whether you are a follower or not.
		@does_follow = false
		profile_user_id = params[:userid].to_i
		if login?
			@session_id = User.where(handle: session[:username]).first.id
			followees = Relationship.where(follower_id: @session_id).pluck(:followed_id)
			followees.each do |followee|
				if followee == profile_user_id
					@does_follow = true
				end
			end
		end
		
		#@num_followers and @num_following display number of followers/followees of the profile owner
		@num_followers = Relationship.count_followers(profile_user_id)
		@num_following = Relationship.count_followees(profile_user_id)
		
		@username = User.find(profile_user_id).handle
		#This returns the 100 latest tweets from this user.
		if REDIS.exists("personal_"+@username) == false
			redis_personal_list_for_user("personal_"+@username, profile_user_id)
		end
		
		
		#This gives us the username of the profile user
		
		
		erb :look, :locals => {:userid => params[:userid]}
	end
end 

#This method creates a follow relationship between the session user and the user being followed.
post "/follow" do
	followed = User.find(params[:userid])
	#NOTE FOR LATER: Perhaps we could change the User.follow(n) method so that n is the user's id instead of the user?
	#This would save us a database lookup.
  User.where(handle: session[:username]).first.follow(followed)
   
  flash[:notice] = "You are following " + followed.handle
  redirect "/user/#{params[:userid]}"
  
end

#This method deletes a follow relationship between the session user and a given user.
post "/unfollow" do
	followed = User.find(params[:userid])
	User.where(handle: session[:username]).first.unfollow(followed)
 
  flash[:notice] = "You are no longer following " + followed.handle
  redirect "/user/#{params[:userid]}"
end

#Displays a list of a user's followers.
get "/followers" do
	id = params[:userid]
	@followers = Relationship.find_followers(id)
	
	erb :followers, :locals => {:userid => id}
end

#Displays a list of a user's followees.
get "/followees" do
	id = params[:userid]
	@followees = Relationship.find_followees(id)
	
	erb :followees, :locals => {:userid => id}
end



