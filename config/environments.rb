#The environment variable DATABASE_URL should be in the following format:
# => postgres://{user}:{password}@{host}:{port}/path
configure :development do
	db = URI.parse(ENV['DATABASE_URL'])
 
	ActiveRecord::Base.establish_connection(
			:adapter => db.scheme == 'sqlite3' : db.scheme,
			:host     => db.host,
			:database => db.path[1..-1],
			:encoding => 'utf8'
	)
end

configure :production do
	db = URI.parse(ENV['DATABASE_URL'] || 'postgres://localhost/mydb')
 
	ActiveRecord::Base.establish_connection(
			:adapter => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
			:host     => db.host,
			:username => db.user,
			:password => db.password,
			:database => db.path[1..-1],
			:encoding => 'utf8'
	)
end