#The environment variable DATABASE_URL should be in the following format:
# => postgres://{user}:{password}@{host}:{port}/path
configure :production, :development do
	db = URI.parse(ENV['DATABASE_URL'])
 
	ActiveRecord::Base.establish_connection(
			:adapter => db.scheme == 'sqlite3' : db.scheme,
			:host     => db.host,
			:database => db.path[1..-1],
			:encoding => 'utf8'
	)
end