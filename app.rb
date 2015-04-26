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
	
		#Dont touch this for now. >>>>>>>>>>>>>>>>>>>>>
		#probs should go into a helper method
		#on initialize flush redis db and recreate top 100 latest tweets
		REDIS.flushdb
		global_tweets = Tweet.search_latest_tweets("")
		global_tweets.each do |tweet|
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
    	if username.nil? || userid.nil?
      		return false
    	else
      		return true
    	end
  	end
  
	#Returns the username of the current logged-in user
  	def username
    	return session[:username]
  	end
	
	#Returns the user id of the current logged-in user
  	def userid
    	return session[:userid]
  	end

	#Redirects to the logged-in user's personal page
	def go_to_profile
		if login?
			#Queries the database for the handle and id of all users that are followed by the session user by 
			#performing a join between the relationships and users tables.
			@followees = Relationship.find_by_sql("SELECT users.handle, users.id FROM relationships 
				INNER JOIN users ON relationships.followed_id = users.id
				WHERE relationships.follower_id = #{userid}
				ORDER BY relationships.created_at desc
				")
			erb :profile
		else
			erb :login
		end
	end

	#Constructs a redis object that lists the last 100 tweets posted by the users with a given set of timeline ids
	#The given set must be formatted in SQL syntax
	#The name of the redis object is name+"_logged"
	def create_cached_logged_in_timeline(name, timeline_ids)
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
			hash[:user_id] = tweet.user_id
			hash[:handle] = tweet.handle
			hash[:text] = tweet.text
			hash[:created_at] = tweet.created_at
			REDIS.lpush(name + "_timeline", hash.to_json)
		end
		REDIS.expire(name + "_timeline", 120)
	end
	
	#produces the list of the text and timestamps of the 100 latest tweets 
	#for a single user and saves them as a redis object
	#The list is named "personal_"+name
	def create_cached_personal_tweet_list(name, user_id)
		#Queries the database for the text and timestamps of the 100 latest tweets
		tweets = Tweet.find_by_sql("SELECT tweets.text, tweets.created_at FROM tweets
			WHERE tweets.user_id = #{user_id}
			ORDER BY created_at DESC
			LIMIT 100")

		tweets.each do |tweet|
			hash = Hash.new
			hash[:text] = tweet.text
			hash[:created_at] = tweet.created_at
			REDIS.lpush(name + "_personal", hash.to_json)
		end
		REDIS.expire(name, 120)

	end

	#Generates a redis object tracking the number of followers for a given user id, with a
	#unique name determined by the name parameter
	def create_cached_follower_count(name, user_id)
		num_followers = Relationship.count_followers(user_id)
		REDIS.set(name+"_num_followers", num_followers)
		REDIS.expire(name+"_num_followers", 120)
	end

	#Generates a redis object tracking the number of followees for a given user id, with a
	#unique name determined by the name parameter
	def create_cached_followee_count(name, user_id)
		num_following = Relationship.count_followees(user_id)
		REDIS.set(name+"_num_following", num_following)
		REDIS.expire(name+"_num_following", 120)
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
		session_id = userid
		timeline_ids = session_id.to_s
		
		#Adds followed users' ids to the list
		followees_relationships = Relationship.where(follower_id: session_id)
		followees = followees_relationships.pluck(:followed_id)
		followees.each do |followee|
			timeline_ids = "#{timeline_ids} , #{followee.to_s}"
		end
		
		
		if REDIS.exists(username+ "_timeline") == false
			create_cached_logged_in_timeline(username, timeline_ids)
		end	
		
		#@num_followed and @num_following display number of followers/followees of the user, respectively
		@num_followers = Relationship.count_followers(session_id)
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
		session[:userid] = user.id
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
end

#Get method for the logout page
get "/logout" do
  session[:username] = nil
  session[:userid] = nil
  redirect "/"
end

#Post method for tweets. Checks if a submitted text is 140 characters or less. If it is, then it is 
#used to create a tweet.
post "/tweet" do
	user = User.find(userid)
	tweet_text = params[:text]
	if tweet_text.length <= 140
		tweet = user.tweet(tweet_text)
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
			followees = Relationship.where(follower_id: userid).pluck(:followed_id)
			followees.each do |followee|
				if followee == profile_user_id
					@does_follow = true
				end
			end
		end
		
		@username = User.find(profile_user_id).handle
		#This saves to cache the 100 latest tweets from the profile user.
		if REDIS.exists(@username+"_personal") == false
			create_cached_personal_tweet_list(@username, profile_user_id)
		end

		#This saves to cache the number of followers of the profile user
		if REDIS.exists(@username+"_num_followers") == false
			create_cached_follower_count(@username, profile_user_id)
		end
		
		#This saves to cache the number of followees of the profile user
		if REDIS.exists(@username+"_num_followees") == false
			create_cached_followee_count(@username, profile_user_id)
		end
		
		erb :look, :locals => {:profile_user_id => params[:userid]}
	end
end 

#This method creates a follow relationship between the session user and the user being followed.
post "/follow" do
	followed = User.find(params[:userid])
	#This method creates the follow relationship in the database
  	User.find(userid).follow(followed)
   
  	flash[:notice] = "You are following " + followed.handle
  	redirect "/user/#{params[:userid]}"
end

#This method deletes a follow relationship between the session user and a given user.
post "/unfollow" do
	followed = User.find(params[:userid])
	#This method deletes the follow relationship in the database
	User.find(userid).unfollow(followed)
 
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


#Routes necessary for final tests
get "/test/setup" do
end