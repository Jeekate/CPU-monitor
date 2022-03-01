--init.lua
-------------
-- define
-------------
nodename = 'node-'..string.gsub(node.chipid(),':','')

pwm.setup(4, 1000, 512)
pwm.start(4)
gpio.mode(4, gpio.OPENDRAIN)
-- node.setcpufreq(node.CPU160MHZ)
-------------
-- wifi
-------------
wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
	print("\n\tSTA - GOT IP!"..
				"\n\tStation IP: "..T.IP..
				"\n\tSubnet mask: "..T.netmask..
				"\n\tGateway IP: "..T.gateway)
	mdns.register(nodename, {hardware='NodeMCU-'..node.chipid(),service='cpuinfo'})
	wifi.setmode(wifi.STATION)
	---net.dns.setdnsserver("8.8.8.8", 1)
end)

print('Setting up WIFI...')
wifi.setmaxtxpower(82)
wifi.setphymode(wifi.PHYMODE_B)
wifi.setmode(wifi.STATIONAP)
wifi.ap.setip({ip='192.168.1.1',
							 netmask='255.255.255.0',
							 gateway='192.168.1.1'})
wifi.ap.config({ ssid = nodename, auth = AUTH_OPEN })

-------------
-- http
-------------
dofile('httpServer.lc')

httpServer:use('/cpu', function(req, res)
	if wifi.sta.getip() == nil then
		return
	end
	if req.query.duty ~= nil or 
		 req.query.pc   ~= nil
	then
		local status
		if req.query.pc   ~= nil
		then
			print('percent:'..req.query.pc..'%')
			status = 'NoOutput'
		end
		if req.query.duty ~= nil
		then			
			local _duty = tonumber(req.query.duty)
			local _pv,_dd,_sv
			if _duty >=0 and 
				 _duty <=1023
			then
				status = 'Ok'
				_pv = pwm.getduty(4)
				_dd = _duty-_pv
				_sv = _pv+_dd*1298/1000
				if _sv>1023 then _sv=1023 end
				if _sv<=0 then _sv=0 end
				pwm.setduty(4, _sv)
				tmr.delay(70000)
				_sv = _pv+_dd*655/1000
				if _sv>1023 then _sv=1023 end
				if _sv<=0 then _sv=0 end
				pwm.setduty(4, _sv)
				tmr.delay(70000)
				_sv = _pv+_dd*724/1000
				if _sv>1023 then _sv=1023 end
				if _sv<=0 then _sv=0 end
				pwm.setduty(4, _sv)
				tmr.delay(70000)
				_sv = _pv+_dd
				if _sv>1023 then _sv=1023 end
				if _sv<=0 then _sv=0 end
				pwm.setduty(4, _sv)
				tmr.delay(70000)
			else
				status = 'OutOfRange'
				print('out of range')
			end
		end
		res:type('application/json')
		res:send('{"status":"'..status..'"}')
	end
end)

httpServer:use('/config', function(req, res)
	local function sendState(s)
		res:type('application/json')
		res:send('{"status":"' .. s .. '"}')
	end
	if req.query.ssid ~= nil and 
		 req.query.pwd ~= nil and
		 req.query.ssid ~= ''
	then
		local sconfig={}
		sconfig.ssid=req.query.ssid
		sconfig.pwd=req.query.pwd
		sconfig.save=true
		
		wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(T)
			print("\n\tSTA - DISCONNECTED".."\n\tSSID: "..T.SSID.."\n\tBSSID: "..
			T.BSSID.."\n\treason: "..T.reason)
			if T.reason == 201 then
				sendState('STA_APNOTFOUND')
			elseif T.reason == 15 then
				sendState('STA_WRONGPWD')
			elseif T.reason == 8 or 
						 T.reason == 2 or 
						 T.reason == 3 or 
						 T.reason == 202 then
				return--active disconnect, no sending msg
			else
				sendState(T.reason)
			end
			wifi.sta.disconnect()
			wifi.eventmon.unregister(wifi.eventmon.STA_DISCONNECTED)
		end)
		
		wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
			print("\n\tSTA - GOT IP"..
						"\n\tStation IP: "..T.IP..
						"\n\tSubnet mask: "..T.netmask..
						"\n\tGateway IP: "..T.gateway)
			wifi.eventmon.unregister(wifi.eventmon.STA_GOT_IP)
			mdns.register(nodename, {hardware='NodeMCU-'..node.chipid(),service='cpuinfo'})
			res._apGotIP = true
			sendState('STA_GOTIP')
		end)
		wifi.sta.config(sconfig)
		wifi.sta.autoconnect(1)
	else
		sendState('STA_APNOTFOUND')
	end
end)

httpServer:use('/scanap', function(req, res)
	wifi.sta.getap(function(table)
		local aptable = {}
		for ssid,v in pairs(table) do
			local authmode, rssi, bssid, channel = string.match(v, "([^,]+),([^,]+),([^,]+),([^,]+)")
			aptable[ssid] = {
				authmode = authmode,
				rssi = rssi,
				bssid = bssid,
				channel = channel
			}
		end
		res:type('application/json')
		res:send(sjson.encode(aptable))
	end)
end)

httpServer:listen(80)