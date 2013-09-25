require "socket"
require "zmq"
local ffi = require "ffi"
ffi.cdef "unsigned int usleep(unsigned int nanoseconds);"

-- require "zhelpers"
local mp = require 'MessagePack'

local context = zmq.init(1)

--  Socket to send messages on
local sender = context:socket(zmq.PUSH)
sender:bind("tcp://*:5556")

-- responses come back through this one.
local receiver = context:socket(zmq.PULL)
receiver:bind("tcp://*:5557")

local length = 0

local url = arg[1]
local time = tonumber(arg[2])
local concurrency = tonumber(arg[3])
local requests = tonumber(arg[4])

if requests < concurrency then
	concurrency = requests
end


local responses = {}
local msg = mp.pack( {cmd="request",data={url=url}} )

function send_requests (socket,message,number)
	local i = 0
	while i < number do
		-- print("sent a message")
		socket:send(message)
		i = i +1
	end
end



function accumulate_responses(receiver,bucket,limit)
	local i = 0
	while i < limit do
		-- io.write("\r",i," ",limit)
		local msg = receiver:recv()
		-- print("before",msg)
		local cmd = mp.unpack(msg)
		-- print("after",cmd)
		table.insert(bucket.reqs,cmd.time)
		i = i + 1
	end
	-- io.write(" ")
end



local worker = concurrency
print("starting workers...")
while worker > 0 do
	local child = io.popen("luajit ./http_request.lua")
	local msg = receiver:recv()
	local command = mp.unpack(msg)
	worker = worker - 1
end

-- prime the pump so that we always have something to work on.
-- print("priming the pump")
send_requests(sender,msg,concurrency)
-- print("done priming the pump")

local current = 0
while current < time do
	local starttime = socket.gettime()
	send_requests(sender,msg,requests)

	local bucket = {reqs={}}
	responses[current] = bucket
	accumulate_responses(receiver,bucket,requests)
	
	local endtime = socket.gettime()
	local diff = (endtime - (starttime + 1))
	if diff > 1 then
		local behind = math.floor(diff*1000000)
		current = current + behind
		print("behind by",behind,"nano seconds")
	else if diff < 0 then
			print("sleeping for",math.floor(-diff*1000000),"nano secconds")
			ffi.C.usleep(math.floor(-diff*1000000))
		end
		current = current + 1
	end
end



local die = mp.pack({cmd= "exit"})
print("enqueing stop worker commands...")
while concurrency > 0 do
	sender:send(die)
	concurrency = concurrency - 1
end

print("\n(in milliseconds)")
print("second","avg","mean","min","max","requests")

local prev = 0
local offset = 0
local i = 0
while i <= time do
	data = responses[i]
	i = i + 1
	if prev == 0 then
		offset = 1
	else
		offset = offset + i - prev
	end
	if data == nil then
		-- print("na.",start_time)
	else
		-- print(start_time)
		prev = i
		local avg = 0
		local total = 0
		local mean = 0
		local min= math.huge
		local max= -math.huge
		local prev = nil
		for id,time in pairs(data.reqs) do
			-- print("data point:",second,time)
			total = total + 1
			avg = avg + time
			if time < min then min = time end
			if time > max then max = time end
		end
		avg = avg / total
		print(offset,math.floor(avg)/10,math.floor(mean)/10,math.floor(min)/10,math.floor(max)/10,total)
	end
end

ffi.C.usleep(1000000)              --  Give 0MQ time to deliver

sender:close()
receiver:close()
context:term()