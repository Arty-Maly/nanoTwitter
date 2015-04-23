require 'sinatra/activerecord'	
require 'bcrypt'
require 'faker'
require './models/user'
require './models/tweet'
require './models/relationship'

password = '12345'
@users = Array.new

users = File.open("tmp/users.csv")
follows = File.open("tmp/follows.csv")
tweets = File.open("tmp/tweets.csv")
i = 0


users.each_line do |line|
 	split = line.split(',')
	hash = Hash.new
	hash[:handle] = split[1]
	hash[:password] = password
	User.create(hash)
	i +=1
end
i = 1

tweets.each_line do |line|
	split = line.split('"')

	hash = Hash.new
	tweet = User.find(split[0].delete!(",")).tweets.create(text: split[1], user_id: split[0])
	tweet.created_at = (split[2].delete!(",")[0..-7])
	tweet.save
	
	i+=1

end

follows.each_line do |line|
	split = line.split(",")
	begin
		User.find(split[0]).follow(User.find(split[1]))
	rescue ActiveRecord::RecordNotUnique => e
	end
end

# 30.times do
# 	hash = Hash.new
# 	hash[:handle] = Faker::Internet.user_name
# 	hash[:password] = password
	
# 	@users.push(User.create(hash))

# end

# 10.times do

# 	@users.each do |user|
# 		user.tweets.create(text: Faker::Hacker.say_something_smart)
# 	end
# end


# 10.times do 
# 	@users.each do |user|
# 		begin
			
# 			user.follow(User.find(Random.new.rand(1..30)))	
# 		rescue ActiveRecord::RecordNotUnique => e
# 		end
# 	end
# end