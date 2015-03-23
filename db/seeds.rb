require 'sinatra/activerecord'	
require 'bcrypt'
require 'faker'
require './models/user'
require './models/tweet'
require './models/relationship'

password = '12345'
@users = Array.new


30.times do
	hash = Hash.new
	hash[:handle] = Faker::Internet.user_name
	hash[:password] = password
	
	@users.push(User.create(hash))

end

10.times do

	@users.each do |user|
		user.tweets.create(text: Faker::Hacker.say_something_smart)
	end
end


10.times do 
	@users.each do |user|
		begin
			
			user.follow(User.find(Random.new.rand(1..30)))	
		rescue ActiveRecord::RecordNotUnique => e
		end
	end
end