source 'https://rubygems.org'

gem "sinatra"
gem "activerecord"
gem "sinatra-activerecord"
gem "shotgun"
gem 'bcrypt'
gem "sinatra-flash"
gem 'rack-flash3'
gem 'rack-test'

gem 'faker'
gem 'rake'

group :test do
	gem 'sqlite3'
end
group :development do
	gem 'sqlite3'
end
group :production do
	gem 'pg'
	gem 'activerecord-postgresql-adapter'
end
