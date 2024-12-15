#!/bin/lua

-- A game independant mod manager by superpowers04
-- BACKUP YOUR GAME, THIS MOD MANAGER DOES NOT BACKUP ANY GAME FILES CURRENTLY
-- This setup is for Cyberpunk but no directories are hardcoded besides ManagerMods and MANAGERDOWNLOADS
-- This works by using a bunch of symbolic links. This requires SuperUtils.lua and will probably only work on Linux and POSSIBLY MacOS
-- Currently, the mod manager doesn't keep track of ANY files, it just goes off of the files it finds inside of a mod, so if a file is not included in the zip, it should never be modified
-- 7z is required for the zip command
local util = require('SuperUtils')
insert = table.insert



-- Config
-- Note you can copy this section to a mmconfig.lua and that'll be read instead. 
-- It is highly recommended you do that instead


-- Folders that can be used to identify zips for the game
KnownFolders = { 
	"/r6/",
	'/red4ext/',
	'/engine/',
	"/archive/",
	'/bin/x64/'
}
-- Folders that'll be copied instead of using symlinks
ActuallyCopyFolders={
	"/bin/x64/plugins/cyber_engine_tweaks"
}
-- Will add extra warnings for troubleshooting
minorWarnings = false


-- Actual script

APIKEYS = {}

local succ = pcall(require,'mmconfig')

if not succ then 
	local configFile = io.open('mmconfig.lua','w')
	configFile:write(([[
	-- Example config file, the config file directly uses lua, so it's syntax is required.

	--insert(KnownFolders,"/bin/") -- Adds "/bin/" to the KnownFolders config option

	APIKEYS={ -- API keys for specific services, right now only NexusMods is supported
		NEXUS="", -- You can get an API KEY from https://www.nexusmods.com/users/myaccount?tab=api
		-- To use, you need to click ModManager Download, > Slow/Fast download > Cancel the auto open > Copy the link on "Click Here", then use the download action with the link
	}
	]]):gsub('\n\t','\n'))
	configFile:close()
	print('Example config file generated at mmconfig.lua, please look at it')
end

local arg = arg or args
local pwd = os.getenv('PWD')..'/'
local selection = ""
local cached_action = ""
util.applyExtensions()
local function truthy(b)
    if(b == nil) then return false end
    if(type(b) == "boolean") then return b end
    if(type(b) == "number") then return b == 1 end
    if(type(b) == "string") then 
        local sub = b:sub(1,1):lower()
        return (sub=='y' or sub=='t' or sub == "1")
    end
    return false
end
local function getMod(id)
	local n = tonumber(id)

	if(not n or n ~= n) then 
		if(id:find('/?ManagerMods/')) then
			return id:match('ManagerMods/(.-)/')
		end
		return id
	end
	local list = util.execute('ls -1Nq --color=none','ManagerMods'):split('\n')
	return list[n]
end
local function fileExists(file)
	local file = io.open(file,'r')
	if not file then return false end
	file:close()
	return true
end
local actions
actions = {
	za = function(...)
		for _,v in pairs({...}) do
			actions.zip(v)
		end
	end,
	exportlist = function(file)
		file = file or "ManagerModlists/export.txt"
		if not file:find('/') then
			file = "ManagerModlists/"..file
		end
		local mods = {}
		local modList = util.execute('ls -1Nq --color=none','ManagerMods'):split('\n')
		for i,mod in pairs(modList) do
			local file = io.open('./ManagerMods/'..mod..'/enabled','r')
			if(file) then
				file:close()
				mods[#mods+1] = mod
			end
		end

		util.execute('mkdir -p',file:match('.+/'))
		local out = io.open(file,'w')
		out:write(table.concat(mods,'\n'))
		out:close()
		printf('Exported %i mods to %s',#mods,file)
	end,
	importlist = function(file)
		file = file or "ManagerModlists/export.txt"
		if not file:find('/') then
			file = "ManagerModlists/"..file
		end
		local mods = {}
		local listFile = io.open(file,'r')

		if not listFile then return printf('%s is not a valid list',file) end
		local installedModsList = util.execute('ls -1Nq --color=none','ManagerMods'):split('\n')
		local modList = listFile:read('*a'):split('\n')
		listFile:close()
		local unfoundMods = {}
		for i,mod in pairs(modList) do
			local plainList = util.execute('find','ManagerMods/'..mod)
			if not plainList or plainList == "" then 
				unfoundMods[#unfoundMods+1] = mod
				printf('%s was not found, search queued!',mod)
			else
				actions.install(mod)
			end
		end
		if(#unfoundMods > 0) then
			printf('Unable to find %i mods TODO: ADD SUPPORT FOR AUTOFINDING MODS')
		end
		print('Finished importing list')
	end,
	zip = function(...)
		local file = table.concat({...},' ')
		local mod = file:match('/([^/]+)%.')
		actions.zipnamed(file,mod)
	end,
	zipnamed = function(file,mod)
		
		util.execute('mkdir','./MANAGERDOWNLOADS')
		-- if(file:find('https'))
		printf('Extracting....')
		util.execute('7z X',file,'-o./MANAGERDOWNLOADS')
		local fileList = util.execute('find','./MANAGERDOWNLOADS')
		printf('Searching for known folders...')
		for i,v in ipairs(KnownFolders) do
			local match = fileList:match('([^\n]+)'..v)
			if(match) then
				-- actions.registermoddedfile(mod,table.unpack(util.execute('find',match):split('\n')))
				printf('Mod is valid, attempting to remove any older versions..')
				actions.delete(mod)
				local _mod,mod = mod,'./ManagerMods/'..getMod(mod)..'/'
				for _,item in pairs(util.execute('find',match..'/','-type','f'):split('\n')) do
					-- print(item)
					if item and item ~= "" and item ~= "/"  then
						local endResult = mod..(item:sub(#match+2))
						
						util.execute('mkdir -p ',endResult:match('.+/'))
						util.execute('mv ',item,endResult)
						printf('%q > %q',item,endResult)
					end
				end
				local dirsLeft = 1
				local deletedDirs = 1
				local limit = 1000
				print('Cleaning up dirs')
				local directories = util.execute('find',match..'/','-type','d'):split('\n')
				while dirsLeft > 0 and deletedDirs > 0 and limit > 0 do
					dirsLeft = 0
					deletedDirs = 0

					for i=#directories,1,-1 do
						local dir = directories[i]
						local out = util.execute(('rmdir %q 2&>1'):format(dir))
						if(not out or out == "") then
							deletedDirs = deletedDirs + 1
							printf('Removed %q',dir)
						elseif(out:find('not empty')) then
							dirsLeft = dirsLeft + 1
							printf('%q is not empty!',dir)
						end
					end
					limit = limit - 1
				end
				if(limit <= 0) then
					print('MANAGERDOWNLOADS was NOT emptied!')
				end
				actions.stripver(_mod)
				printf('Imported %s to %s successfully!',_mod,mod)
				return
			end

		end
		print('Unable to automatically import mod!')
		return
	end,
	listfiles = function(mod)
		local p = 'ManagerMods/'..getMod(mod)
		printf('Contents of %q\n---------------\n',p)
		local list = util.execute('find',p):split('\n');
		for i,v in pairs(list) do
			local v = v:sub(#p+1)
			if(v ~= "" and v ~= " ") then print(v) end
		end
		print('---------------\n')
		return
	end,
	stripversions = function()
		local modList = util.execute('ls ManagerMods/'):split('\n')
		for i,v in pairs(modList) do
			actions.stripver(v)
		end
		return
	end,
	stripver = function(mod)
		v = './ManagerMods/'.. getMod(mod)
		local plainList = util.execute('find',v)
		if not plainList or plainList == "" then return printf('%s is not a valid mod!',modName) end
		local e,version = v:match('(.-)( ?v?[%._%-0-9]+)$')
		if(e and version and version ~= "") then
			local enabled = fileExists(v..'/enabled')
			if(enabled) then
				actions.remove(mod)
			end
			version = version:gsub('^[%-_ ]+',''):gsub('[ _-]*$','')
			util.execute('mv',v,e)
			local file = io.open(e..'/MMVERSION','w')
			file:write(version or "INVALID")
			file:close()
			print(('%s > %s'):format(v,e))
			if(enabled) then
				actions.enable(e)
			end
		end
		return
	end,
	list = function(sort)
		local _modList = util.execute('ls -1Nq --color=none','ManagerMods'):split('\n')
		local modList,versions = {},{},{}
		local shouldSort = sort ~= nil
		sort = truthy(sort)
		local VERSIONSIZE = 0
		for i,v in pairs(_modList) do
			local file = io.open('./ManagerMods/'..v..'/MMVERSION','r')
			if(file) then
				version = file:read('*a')
				versions[v] = version
				file:close()
				if(VERSIONSIZE < #version) then
					VERSIONSIZE = #version
				end
			end
		end
		for i,v in pairs(_modList) do
			local str = tostring(i)
			local size = str .. (' '):rep(4-#str)
			local version = versions[v] or "N/A"
			local enabled = fileExists('./ManagerMods/'..v..'/enabled')
			local txt = size .. ' | ' .. (enabled and "*" or ' ') ..' | '..version..(" "):rep(VERSIONSIZE-#version)..' | '.. v
			if(shouldSort) then
				if(enabled == sort) then
					modList[#modList+1] = txt
				end
			else
				modList[i] = txt

			end
		end
		print('ID   | ? | Ver  | Folder  | \n---------------\n'..table.concat(modList,'\n'))
		return
	end,
	p = function(mod)
		printf('Targeted mod is %q',getMod(mod))
	end,
	remove = function(mod,force,allowFuzzy)
		if not mod or mod == "" then return printf('No mod specified!') end
		mod = getMod(mod)
		local modName = getMod(mod)
		if not truthy(allowFuzzy) then modName = modName .. '/' end
		local plainList = util.execute('find','ManagerMods/'..modName)
		if not plainList or plainList == "" then return printf('%s is not a valid mod!',modName) end
		-- local list = {}
		plainList = plainList:gsub('^[^\n+]\n','')

		local force = truthy(force)
		local nameLength = #modName
		local directories = {}
		print('Unlinking files')

		for _file in plainList:gmatch('(ManagerMods/([^\n]-/[^\n]+))') do
			local file = './'.._file:sub(13+nameLength)
			if(file ~= "./" and #file > 3 and #_file > 14+nameLength) then
				local ftype = util.execute('file',file)
				local isLink = ftype:find('link to ')
				local manualFile = false
				for i,v in pairs(ActuallyCopyFolders) do
					if(file:sub(2,#v+1) == v) then
						manualFile = true
						break
					end
				end
				if(ftype:find('%(No such file or directory%)')) then
					if(minorWarnings) then
						printf('%q is NOT a valid file!',file)
					end
				elseif(ftype:find('directory')) then
					directories[#directories+1] = file
				elseif(not force and not isLink and not manualFile) then
					printf('%q is NOT a link! (%s)',file,ftype)
				else
					printf('%s %q',manualFile and "Deleting" or "Unlinking",file)
					util.execute('unlink',file)
					util.execute('rmdir',file:match('.+/'))
				end
			end
			-- list[#list] = file
		end
		local dirsLeft = 1
		local deletedDirs = 1
		local limit = 1000
		print('Cleaning up dirs')
		while dirsLeft > 0 and deletedDirs > 0 and limit > 0 do
			dirsLeft = 0
			deletedDirs = 0

			for i=#directories,1,-1 do
				local dir = directories[i]
				local out = util.execute(('rmdir %q 2&>1'):format(dir))
				if(not out or out == "") then
					deletedDirs = deletedDirs + 1
					printf('Removed %q',dir)
				elseif(out:find('not empty')) then
					dirsLeft = dirsLeft + 1
					printf('%q is not empty!',dir)
				end
			end
			limit = limit - 1
		end
		util.execute('unlink','ManagerMods/'..modName..'/enabled')
		printf('Finished')
	end,
	download = function(url,name)
		if not url then return printf('Missing URL!') end
		if(url:find('nxm://')) then
			local game,mod,file = url:match("nxm://([^/]+)/mods/(%d+)/files/(%d+)")
			local extra = ""
			-- key=nZHadfXccAzcjwFaeX7dGQ&expires=1734410077&user_id=94294328
			if(url:find('?')) then
				extra = url:match("nxm://[^/]+/mods/%d+/files/%d+%?(.+)")
			end
			-- local key,expires,user_id = url:match('key=([^&]+)'),url:match('expires=([^&]+)'),url:match('user_id=([^&]+)')
			if not game or not mod or not file then
				return printf('Invalid nexus mod manager url!')
			end
			url = ('nexusmods.com/%s/mods/%s?file_id=%s&%s'):format(game,mod,file,extra)
		end
		if(url:find('nexusmods.com')) then
			if not APIKEYS.NEXUS or APIKEYS.NEXUS == "" then
				return printf('Downloading from nexus requires an API key, check mmconfig.lua for more information about how to add one!')
			end
			local game,mod,file,extra = url:match('nexusmods.com/([^/]+)/mods/(%d+).-file_id=(%d+)(.+)')
			print(game,mod,file,extra,url)
			if not game or not mod or not file then
				return printf('Invalid nexusmods url! You need to copy the link from the "manual download" button')
			end
			local response = util.exec('curl',
				('https://api.nexusmods.com/v1/games/%s/mods/%s/files/%s/download_link.json?%s'):format(game,mod,file,extra or ""),
				"-H",("apikey: %s"):format(APIKEYS.NEXUS),
				"-H","Application-Version: 0.0.1",
				"-H","Application-Name: SupersBadModManager"
			)

			url = response:match('"URI":"(.-)"')
			if not url then
				return printf('Nexus sent an invalid response! Maybe you copied the wrong link? You need to copy the link from the "manual download" button\n%s',response)
			end
			url = url:gsub('\\u(%d%d%d%d)',function(a) return utf8.char(tonumber(a)+12) end)
		end
		local MODNAME,version = nil, "dl date: "..os.date('%x')
		if not name then 
			name = url:match('.+/([^?]+)%.')
			local _version = name:match('( ?v?[%._%-0-9]+)$')
			if(_version) then
				name,version = name:sub(0,-(#_version+1)),_version
			end
		else
			local _version = url:match('.+/([^?]+)%.[^?]+'):match('( ?v?[%._%-0-9]+)$')
			if(_version) then
				version = _version
			end

		end
		version = version:gsub('^[%-_ ]+',''):gsub('[ _-]*$','')

		local extension = url:match('[^?]+(%.[^?]+)')
		local file = '/tmp/MANAGERMODSTEMP'..extension
		printf('Downloading %s.\n Name:%s Version:%s',url,name,version)
		util.exec('wget','--quiet','--show-progress',url,'-O'..file)
		local output = io.open(file,'r')
		if not output then
			return printf('Unable to find downloaded file!')
		end
		util.execute('mkdir','./MANAGERDOWNLOADS')
		if(version) then
			local v = io.open('MANAGERDOWNLOADS/MMVERSION','w')
			if v then 
				v:write(version)
				v:close()
			else
				printf('UNABLE TO WRITE VERSION TO MANAGERDOWNLOADS/MMVERSION')
			end
		end
		output:close()
		actions.zipnamed(file,name)
		util.execute('rm '..file)
	end,
	install = function(mod,force,allowFuzzy,forceCopy)
		if not mod or mod == ""  then return printf('No mod specified!') end
		mod = getMod(mod)
		local modName = mod
		if not (truthy(allowFuzzy)) then modName = modName .. '/' end
		local plainList = util.execute('find','ManagerMods/'..modName,'-type','f')
		if not plainList or plainList == "" then return printf('%s is not a valid mod!',modName) end
		forceCopy = truthy(forceCopy)
		force = truthy(force) or forceCopy
		local nameLength = #modName
		for _file in plainList:gmatch('(ManagerMods/(.-/[^\n]+))') do
			local path = pwd.._file
			local file = './'.._file:sub(13+nameLength)
			local ftype = util.execute('file',file)
			local isLink = ftype:find('link to ')
			local manualFile = false
			for i,v in pairs(ActuallyCopyFolders) do
				if(file:sub(2,#v+1) == v) then
					manualFile = true
					break
				end
			end
			if(not force and not isLink and not ftype:find('%(No such file or directory%)')) then
				printf('%q is an existing file! (%s)',file,ftype)
			elseif forceCopy or manualFile then
				printf('Copying %q',file)
				if(isLink) then
					util.execute('unlink',file)
				end
				util.execute('mkdir -p',file:match('.+/'))
				util.execute('cp ',path,file)
			else
				printf('Linking %q',file)
				if(isLink) then
					util.execute('unlink',file)
				end
				util.execute('mkdir -p',file:match('.+/'))
				util.execute('ln -sr',path,file)
			end
		
			-- list[#list] = file
		end
		local en = io.open('./ManagerMods/'..modName..'/enabled','w')
		en:write('')
		en:close()
		printf('Finished')
	end,
	ia = function(...)
		for _,v in pairs({...}) do
			actions.install(v)
		end
	end,
	ra = function(...)
		for _,v in pairs({...}) do
			actions.remove(v)
		end
	end,
	disableall = function()
		local modList = util.execute('ls -1Nq --color=none','ManagerMods'):split('\n')
		for _,v in pairs(modList) do
			actions.remove(v)
		end
	end,
	delete = function(mod)
		if not mod or mod == "" then return printf('No mod specified!') end
		mod = getMod(mod)
		local modName = getMod(mod)
		if not allowFuzzy then modName = modName .. '/' end
		local plainList = util.execute('find','ManagerMods/'..modName)
		if not plainList or plainList == "" then return printf('%s is not a valid mod!',modName) end
		if(plainList:find("/enabled")) then
			actions.remove(mod)
		end
		local out = '/tmp/BACKUP_'..os.time()..'_'..modName
		util.execute('mv','ManagerMods/'..modName,out)
		printf(('Moved %s to %s'):format('ManagerMods/'..modName,out))
	end,

	-- registermoddedfilelist = function(mod,filelist)
	-- 	if not mod or mod == ""  then return printf('No mod specified!') end
	-- 	if not filelist or filelist == ""  then return printf('No filelist specified!') end
	-- 	mod = './ManagerMods/'..getMod(mod)..'/'
	-- 	local f = io.open(filelist,'r')
	-- 	local list = f:read('*a'):split('\n')
	-- 	f:close()
	-- 	for item in ipairs(list) do
	-- 		local endResult
	-- 		if(item:sub(0,#pwd) == pwd) then
	-- 			endResult = mod..item:sub(#pwd+1)
	-- 		else
	-- 			endResult = mod..item
	-- 		end
	-- 		util.execute('mkdir -p %q',endResult:match('.+/'))
	-- 		util.execute('mv -r %q %q',item,endResult)
	-- 		printf('%q > %q',item,endResult)

	-- 	end
	-- end,
	registermoddedfile = function(mod,...)
		if not mod or mod == ""  then return print('No mod specified!') end
		local files = {...}
		if(cached_action ~= "" and selection ~= "") then
			files = {table.concat(files,' ')}
		end
		mod = './ManagerMods/'..getMod(mod)..'/'
		for _,item in pairs(files) do
			if not item or item == ""  then return print('No file specified!') end
			local endResult
			if(item:sub(0,#pwd) == pwd) then
				endResult = mod..item:sub(#pwd+1)
			else
				for _,v in ipairs(KnownFolders) do
					local validPath = item:match(v..'.-$')
					if validPath then
						item = validPath
					end
				end
				endResult = mod..item
			end
			util.execute('mkdir -p ',endResult:match('.+/'))
			util.execute('mv ',item,endResult)
			printf('%q > %q',item,endResult)
		end
	end,
	help=function()
		printf([[ModManager.lua [ACTION] [ARGUMENTS] - A universal UNIX ONLY mod manager that mostly uses symbolic links to load mods. Originally designed for Cyberpunk.
Actions:
	enable, install, e, i - Enable a mod
		> enable [MODID|MODNAME]
	ia - Enable several mods
		> ia [MODID|MODNAME]...
	disable, remove, d, r - Disable a mod
		> disable [MODID|MODNAME]
	da - Disable several mods
		> da [MODID|MODNAME]...
	delete - Disable and delete a mod
		> delete [MODID|MODNAME]
	list - List all mods
		> list [ONLY SHOW TOGGLED MODS]
	registermoddedfile, rmf - Add a file to an existing mod
		> rmf [MODID|MODNAME]
	zip - Add a mod from a zip
		> zip [FILE]
	zipnamed - Add a mod from a zip and use a custom name
		> zip [FILE] [NAME]
	download - Download a mod from a URL and optionally use a custom name
		> download [URL] [NAME]
	stripver - Strip the version from a mod name and save it's version seperately
		> stripver [MODID|MODNAME]
	stripversions - Runs stripver on ALL mods
		> stripversions
	importlist - Imports a list of mods from a txt file (UNFINISHED)
		> importlist [file]
	exportlist - Exports a list of mods to a txt file
		> exportlist [file]
		]])
	end
}

actions.r = actions.remove
actions.disable = actions.remove
actions.d = actions.disable
actions.lf = actions.listfiles
actions.i = actions.install
actions.enable = actions.install
actions.e = actions.enable
actions.rmf = actions.registermoddedfile
actions.rmfl = actions.registermoddedfilelist
actions.l = actions.list
a = {}
for i in pairs(actions) do
	table.insert(a,i)
end
table.sort(a)
util.execute('rm -r "./MANAGERDOWNLOADS"')
actions.tui = function()

	local aliases = {
		lf="List Files",
		a="Set Action",
		r="Remove",
		i='Install',
		rmf="Register Modded File",
		rmfl="Register Modded File List",
		


	}
	actions.select = function(a)
		selection = getMod(a or "")
	end
	actions.q = os.exit
	actions.quit = os.exit
	actions.reset = function(a)
		selection,cached_action = "",""
	end
	actions.s = actions.select
	actions.setaction = function(a)
		if(aliases[a]) then a = aliases[a] end
		if a and a ~= "" and not actions[a:lower():gsub(' ','')] then
			printf('%q is not a valid action!',a or "")
			return
		end
		cached_action = a or ""
		printf('Set selected action to %q',a)

	end
	actions.a = actions.setaction
	while true do
		os.execute('clear')
		actions.list()
		printf('---------------\nSelected mod: %q, Selected action: %s\nUse help for a list of actions',selection,cached_action,table.concat(a,', '))
		local cmd = util.splitCommand(io.read())
		if(#cmd <= 0) then
			print('Nothing to do')
			io.read()
			goto continue
		end
		local action_string = tostring(cmd[1]):lower():gsub(' ','')
		local action = actions[action_string]
		if not action and cached_action ~= "" then
			action_string = cached_action:lower():gsub(' ','')
			action = actions[action_string]
		else
			table.remove(cmd,1)
		end
		if action then
			if(action ~= actions.s and action ~= actions.a and selection and selection ~= "") then
				table.insert(cmd,1,selection)
			end
			action(table.unpack(cmd))
			print('Press enter to continue')
			io.read()
		else
			printf('%q is not a valid action!',action_string)
			io.read()
		end
		::continue::
	end
end
local action = actions[tostring(arg[1]):lower()]
if not action then
	print(('%q is not a valid command'):format(arg[1] or ""))
	actions.help()
	return 
end
table.remove(arg,1)
action(table.unpack(arg))
