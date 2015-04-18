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

end