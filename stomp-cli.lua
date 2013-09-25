require "socket"
require "zmq"
local ffi = require "ffi"
ffi.cdef "unsigned int sleep(unsigned int seconds);"

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

if requests == nil then
	requests = concurrency
end
print("hitting",url,"for",time,"seconds with",concurrency,"workers processing",requests,"reqs/sec")
local total_requests = 0

local spawned = 0
local children = {}

local worker = concurrency
print("starting workers...")
while worker > 0 do
	local child = io.popen("luajit ./http_request.lua")
	table.insert(children,child)
	local msg = receiver:recv()
	local command = mp.unpack(msg)
	-- print("child reported",command.ready)

	worker = worker - 1
end
ffi.C.sleep(1)
local start_time = math.floor(socket.gettime())
while length < time do
	io.write(".")
	io.flush()
	local req = 0
	
	local count = 0
	while count < requests do
		sender:send(msg)
		count = count + 1
	end	
	total_requests = total_requests + count
	
	ffi.C.sleep(1)
	length = length +1
end
print()
local count = 0
local buckets = {}
print("collecting",total_requests,"responses..")
while count < total_requests do

	local msg = receiver:recv()
	local command = mp.unpack(msg)
	local bucket = buckets[command.start]
	if bucket == nil then
		bucket = {
			reqs = {}
		}
		buckets[command.start] = bucket
	end
	table.insert(bucket.reqs,command.time)
	-- print (command.start)
	io.write("\r",count,"/",total_requests)
	count = count + 1
end
local end_time = math.floor(socket.gettime())

local msg = mp.pack({cmd= "exit"})
print("enqueing stop worker commands...")
for id,child in pairs(children) do
	sender:send(msg)
end

print("second","avg","mean","min","max","requests")

local prev = 0
local offset = 0
while start_time <= end_time do
	data = buckets[start_time]
	start_time = start_time + 1
	if prev == 0 then
		offset = 1
	else
		offset = offset + start_time - prev
	end
	if data == nil then
		-- print("na.",start_time)
	else
		-- print(start_time)
		prev = start_time
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

ffi.C.sleep(1)              --  Give 0MQ time to deliver

sender:close()
receiver:close()
context:term()





-- se we need to be able to configure one of these correctly.