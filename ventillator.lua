require "socket"
local mp = require 'MessagePack'


require "zmq"
-- require "zhelpers"

local context = zmq.init(1)

--  Socket to receive messages on
local receiver = context:socket(zmq.PULL)
receiver:bind("tcp://*:5556")

--  Socket to send messages on
local sender = context:socket(zmq.PUSH)
sender:bind("tcp://*:5557")

while true do
	local msg = receiver:recv()
	local command = mp.unpack(msg)
	if command.done == true then
		sender:send(msg)
	else
		local req = 0
		while req < command.concurrency do
			-- print("sending request #",req)
			local msg = mp.pack {job_id=command.job_id,url=command.url}
			sender:send(msg)
			req = req + 1
		end
	end
		
end
sender:close()
context:term()