class Tweet < ActiveRecord::Base
	belongs_to :user

	def self.tweet_search(text)

		puts"========================================================="
		puts text
		return self.limit(20).order("id desc").where('text LIKE ?', "%#{text}%")

	end

	def self.timeline_search(user_id)


	return self.limit(5).order("id desc").where(user_id: user_id)

	end
end