require "zmq"
local mp = require 'MessagePack'
local io = require "io"
-- require"zhelpers"

--  Prepare our context and socket
local context = zmq.init(1)
local receiver = context:socket(zmq.PULL)
receiver:bind("tcp://*:5558")

local stats = {}
while true do
    local msg = receiver:recv()
    local data = mp.unpack(msg)
    local current = stats[data.job_id]
    if data.done == true and stats[data.job_id] ~= nill then
    	print()
    	print("done with batch ",data.job_id)
    	print()
    	print("minimum response time:",current.min)
    	print("average response time:",current.avg)
    	print("maximum response time:",current.max)
    	if current.codes ~= nil then
	    	for code,data in pairs(current.codes) do 
	    		print()
	    		print("got ",data.count," responses with a status of ",code)
	    		print("example response (first received):")
	    		for name,value in pairs(data.example.headers) do 
		    		print(name,":",value)
		    	end
	    		print()
	    		print(data.example.body)
	    	end
	    end
    	stats[data.job_id] = nil
    else
    	if current == nil then
    		print("new batch")
    		current = {
    			codes={},
    			count=0,
    			points={},
    			avg=0,
    			min=math.huge,
    			max=-math.huge,
    		}
    		stats[data.job_id] = current
    	end
	    -- print("id:\t",data.job_id,"second:\t",data.start,"time:\t",math.floor(data.time)," code:\t",data.code)
	    if current.codes[data.code] == nil then 
	    	current.codes[data.code] = {
		    	count = 0,
		    	example = {
		    		body= data.body,
		    		headers= data.headers
		    	}
	    	}
	    end
	    current.codes[data.code].count = current.codes[data.code].count + 1
	    current.avg = current.avg*(current.count/(current.count+1)) + data.time*(1/(current.count+1))
	    current.count = current.count + 1
	    io.write("\r",data.job_id," collected ",current.count," responses")
	    io.flush()
	    if current.min > data.time then 
	    	current.min = data.time
	    end
	    if current.max < data.time then 
	    	current.max = data.time
	    end
	end

end


receiver:close()
context:term()