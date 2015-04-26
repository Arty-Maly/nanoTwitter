class Tweet < ActiveRecord::Base
	belongs_to :user

	#Returns a list of the user ids, usernames, timestamps, and texts of the 100 latest tweets 
	#containing a given phrase, in descending order
	def self.search_latest_tweets(text)
		self.find_by_sql("
			SELECT tweets.text, tweets.user_id, tweets.created_at, users.handle FROM tweets
			INNER JOIN users ON tweets.user_id = users.id
			WHERE tweets.text LIKE '%#{text}%'
			ORDER BY tweets.created_at desc
			LIMIT 100
			")
	
	end

	#Retrieves a list of the user ids, usernames, timestamps, and texts of the last 100 tweets 
	#posted by a set of users, ordered from most recent to oldest, 
	#given a set of user ids as input
	def self.search_latest_tweets_by_users(user_ids)
		#The array is converted to a string format
		#This concatenated string format is necessary in order to make the set compatible with SQL syntax
		user_ids_string = user_ids[0].to_s
		user_ids[1..user_ids.length].each do |id|
			user_ids_string = "#{user_ids_string} , #{id}"
		end

		#Queries the database for the necessary information
		self.find_by_sql("
			SELECT tweets.text, tweets.user_id, tweets.created_at, users.handle FROM tweets
			INNER JOIN users ON tweets.user_id = users.id
			WHERE tweets.user_id IN (#{user_ids_string})
			ORDER BY tweets.created_at desc
			LIMIT 100
			")
	end
end