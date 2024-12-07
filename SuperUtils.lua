-- A bunch of random utilities.

local SuperUtils = {}
local su = SuperUtils
function SuperUtils.execute(...)
	local args = {...}
	for i,v in pairs(args) do
		args[i] = v:gsub('[%[%]:&~|`!%{%};%(%)%*#]','\\%1')
	end
	local cmd = (('%s' .. (" %q"):rep(#args-1)):format(...))
	local f = io.popen(cmd,'r')
	local out = f:read('*a')
	return out,f:close()
end
local outputMT = {
	__type="command output",
	__tostring=function(self)
		return self.out
	end,
	__concat=function(a,b)
		return a.out..b
	end,
	__add=function(a,b)
		return a.code+b
	end,

} outputMT.__index = string
SuperUtils.outputMT = outputMT
outputMT.new = function(self,o,s,t,c)
	return setmetatable({
		out=o,ok=s,type=t,exitcode=c,code=c
	},self)
end

local execMT = {
	__call = function(self,...)
		local args = {self.cmd,...}
		for i,v in pairs(args) do
			args[i] = v:gsub('[%[%]:&~|`!%{%};%(%)%*#]','\\%1')
		end
		local cmd = (('%s' .. (" %q"):rep(#args-1)):format(table.unpack(args)))
		if(self.pre) then cmd = self.pre .. cmd  end
		local f = io.popen(cmd,'r')
		local out = f:read('*a')
		return outputMT:new(out,f:close())
	end,
	__type="command",
	__tostring=function(self)
		return ("%s"):format(self.cmd)
	end
}
SuperUtils.execMT=execMT
local fexecMT = {
	__call = function(self,...)
		return self.f(...)
	end,
	__type=execMT.__type,
	__tostring=execMT.__tostring
}
SuperUtils.makeExec = function(a)
	return setmetatable({cmd = a,pre=""},execMT)
end
SuperUtils.fakeExec=function(e,a)
	return setmetatable({cmd=e,f=a,pre=""},fexecMT)
end
SuperUtils.exec = SuperUtils.execute
function SuperUtils.splitCommand(cmd)
	local ret,cs,in_quote,ignore_next = {}, {}
	for i,v in su.string_iterator(cmd) do
		if(ignore_next) then 
			ignore_next = false
			if v ~= " " then cs[#cs+1] = "\\"..v end
		else
			if(v == "\\") then 
				ignore_next = true
			elseif(v == in_quote) then
				in_quote = false
			elseif(v == " " and not in_quote) then
				ret[#ret+1] = table.concat(cs,'')
				cs = {}
			elseif(v == "\"" or v == "'") then
				in_quote = v
			else
				cs[#cs+1] = v
			end
		end
	end
	if(#cs > 0) then ret[#ret+1] = table.concat(cs,'') end
	return ret
end
function SuperUtils.string_split(a,b)
	local out = {}
	for i in a:gmatch('[^' .. (b or "") .. ']+') do
		out[#out+1]=i
	end
	return out
end
function SuperUtils.string_it(a,i)
	local i = i + 1
	if(i > #a) then return end
	local v = a:sub(i,i)
	if not v then return end
	return i, v
end
function SuperUtils.string_iterator(a)
	return SuperUtils.string_it,a,0
end
function SuperUtils.string_allMatching(a,b)
	local out = {}
	for i in a:gmatch(b or ".") do
		out[#out+1]=i
	end
	return out
end
function SuperUtils.string_count(a,b)
	local out = 0
	for i in a:gmatch(b or ".") do
		out = out + 1
	end
	return out
end
function SuperUtils.applyExtensions()
	string.split = SuperUtils.string_split
	string.allMatching = SuperUtils.string_allMatching
	string.count = SuperUtils.string_count
	string.iterator = SuperUtils.string_iterator
	function printf(a,...)
		print(a:format(...))
	end
end



return SuperUtils