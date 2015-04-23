require "redis"
uri = URI.parse('redis://redistogo:17cc699f654f1fa72cda265ad85d7dd2@barb.redistogo.com:9052/')
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)