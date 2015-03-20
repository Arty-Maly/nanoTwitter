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
		erb :main
	else
		erb :login
	end
end


post "/tweet" do
	user = User.where(handle: username).first
	tweet = user.tweets.create(text: params[:text])
	redirect "/main"
end


post "/tweet_search" do 

  puts params[:tweet_search]
	@search_results = Tweet.tweet_search(params[:tweet_search])

	erb :search
end


get "/look" do 

  erb :look, :locals => {:userid => params[:userid]}
end 

post "/follow" do

  puts "=========================================="
  
  User.where(handle: session[:username]).first.follow(User.find(params[:userid]))
   puts "============================================="
  User.find(params[:userid]).follow(User.where(handle: session[:username]).first)
  puts "============================================="
  flash[:notice] = "Yo are following " + User.find(params[:userid]).handle
  redirect "/look?userid=#{params[:userid]}"
  
end

































