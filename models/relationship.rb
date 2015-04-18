class Relationship < ActiveRecord::Base

	belongs_to :follower, class_name: "User"
	belongs_to :followed, class_name: "User"
	
	validates :follower_id, presence: true
 	validates :followed_id, presence: true
	
	#Finds all followers of a user with a given user id
	def self.find_followers(user_id)
		#Queries the database for the handle and id of all users that follow this page's displayed user by performing a join between
		#the relationships and users tables.
		self.find_by_sql("SELECT users.handle, users.id FROM relationships 
		INNER JOIN users ON relationships.follower_id = users.id
		WHERE relationships.followed_id = #{user_id}
		ORDER BY relationships.created_at desc
		")
	end
	
	#Finds all users being followed by a user with a given user id
	def self.find_followees(user_id)
		#Queries the database for the handle and id of all users that are followed by this page's displayed user by 
		#performing a join between the relationships and users tables.
		self.find_by_sql("SELECT users.handle, users.id FROM relationships 
		INNER JOIN users ON relationships.followed_id = users.id
		WHERE relationships.follower_id = #{user_id}
		ORDER BY relationships.created_at desc
		")
	end
	
	#Counts the number of followers of a user, given that user's id
	def self.count_followers(id)
		self.where(followed_id: id).length
	end
	
	#Counts the number of followees of a user, given that user's id
	def self.count_followees(id)
		self.where(follower_id: id).length
	end
end