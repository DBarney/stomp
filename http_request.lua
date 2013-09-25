require "socket"
local mp = require 'MessagePack'
local http = require "socket.http"

require"zmq"
-- require"zhelpers"

local context = zmq.init(1)

--  Socket to receive messages on
local receiver = context:socket(zmq.PULL)
receiver:connect("tcp://localhost:5556")

--  Socket to send messages to
local sender = context:socket(zmq.PUSH)
sender:connect("tcp://localhost:5557")

--  Process tasks forever
print("waiting")
sender:send(mp.pack({ready=true}))
while true do
    local msg = receiver:recv()
    
    local request = mp.unpack(msg)
    if request.cmd == "exit" then
    	break
    else
	    print("got message:",request,request.data.url)
	    local time = socket.gettime()
	    local body, code, headers = http.request(request.data.url)
	    local time = socket.gettime() - time

	    
		-- print(code)
		-- print("total_time:",after - before)

	    --  Send results to sink
	    local stat = mp.pack({time=time*10000,code=code})
	    sender:send(stat)
	end
end
receiver:close()
sender:close()
context:term()

-- use zeromq to pull jobs from a queue,
-- decode using msgpack
-- monitor cpu usage and memory usage
-- pull jobs until cpu and memory are full
-- use coroutines to run jobs until they finish.
-- output stats and encode using msgpack