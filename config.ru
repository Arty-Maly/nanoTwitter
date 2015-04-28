require 'unicorn/worker_killer'

max_request_min =  600
max_request_max =  900

# Max requests per worker
use Unicorn::WorkerKiller::MaxRequests, max_request_min, max_request_max

oom_min = (300) * (1024**2)
oom_max = (320) * (1024**2)

# Max memory size (RSS) per worker
use Unicorn::WorkerKiller::Oom, oom_min, oom_max

require './app'
run Sinatra::Application 
