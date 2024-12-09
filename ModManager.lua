#!/bin/lua

-- A game independant mod manager by superpowers04
-- BACKUP YOUR GAME, THIS MOD MANAGER DOES NOT BACKUP ANY GAME FILES CURRENTLY
-- This setup is for Cyberpunk but no directories are hardcoded besides ManagerMods and MANAGERDOWNLOADS
-- This works by using a bunch of symbolic links. This requires SuperUtils.lua and will probably only work on Linux and POSSIBLY MacOS
-- Currently, the mod manager doesn't keep track of ANY files, it just goes off of the files it finds inside of a mod, so if a file is not included in the zip, it should never be modified
-- 7z is required for the zip command
local util = require('SuperUtils')

-- Config

-- Folders that can be used to identify zips for the game
KnownFolders = { 
	"/r6/",
	'/red4ext/',
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

local arg = arg or args
local pwd = os.getenv('PWD')..'/'
local selection = ""
local cached_action = ""
util.applyExtensions()

local function getMod(id)
	local n = tonumber(id)
	if(not n or n ~= n) then return id end
	local list = util.execute('ls -1Nq --color=none','ManagerMods'):split('\n')
	return list[n]
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
			local plainList = util.execute('find',v)
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
		
		util.execute('mkdir','./MANAGERDOWNLOADS')
		-- if(file:find('https'))

		util.execute('7z X',file,'-o./MANAGERDOWNLOADS')
		local fileList = util.execute('find','./MANAGERDOWNLOADS')
		for i,v in ipairs(KnownFolders) do
			local match = fileList:match('([^\n]+)'..v)
			if(match) then
				-- actions.registermoddedfile(mod,table.unpack(util.execute('find',match):split('\n')))
				mod = './ManagerMods/'..getMod(mod)..'/'
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
				actions.stripver(mod)
				printf('Imported %q successfully!',mod)
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
		local e,version = v:match('(.-)(? v?[%._%-0-9]+)$')
		if(e and version and version ~= "") then
			version = version:gsub('^[%-_ ]+',''):gsub('[ _-]*$','')
			util.execute('mv',v,e)
			local file = io.open(e..'/MMVERSION','w')
			file:write(version or "INVALID")
			file:close()
			print(('%s > %s'):format(v,e))
		end
		return
	end,
	list = function()
		local modList = util.execute('ls -1Nq --color=none','ManagerMods'):split('\n')
		local enabled = {}
		local disabled = {}
		local versions = {}
		local VERSIONSIZE = 0
		for i,v in pairs(modList) do
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
		for i,v in pairs(modList) do
			local str = tostring(i)
			local size = str .. (' '):rep(4-#str)
			local enabled = false
			local version = versions[v] or "N/A"
			local file = io.open('./ManagerMods/'..v..'/enabled','r')
			if(file) then
				file:close()
				enabled = true
			end
			modList[i] = size .. ' | ' .. (enabled and "✔" or '🗙') ..' | '..version..(" "):rep(VERSIONSIZE-#version)..' | '.. v
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
		if not allowFuzzy then modName = modName .. '/' end
		local plainList = util.execute('find','ManagerMods/'..modName)
		if not plainList or plainList == "" then return printf('%s is not a valid mod!',modName) end
		-- local list = {}
		plainList = plainList:gsub('^[^\n+]\n','')

		local force = force and force:sub(1) == "t"
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
	install = function(mod,force,allowFuzzy)
		if not mod or mod == ""  then return printf('No mod specified!') end
		mod = getMod(mod)
		local modName = mod
		if not (allowFuzzy and allowFuzzy == "t") then modName = modName .. '/' end
		local plainList = util.execute('find','ManagerMods/'..modName,'-type','f')
		if not plainList or plainList == "" then return printf('%s is not a valid mod!',modName) end
		local force = force and force:sub(1) == "t"
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
			elseif manualFile then
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
	delete = function(mod)
		if not mod or mod == "" then return printf('No mod specified!') end
		mod = getMod(mod)
		local modName = getMod(mod)
		if not allowFuzzy then modName = modName .. '/' end
		local plainList = util.execute('find','ManagerMods/'..modName)
		if not plainList or plainList == "" then return printf('%s is not a valid mod!',modName) end
		if(plainList:find(modName.."/enabled")) then
			actions.remove(mod)
		end
		util.execute('mv','ManagerMods/'..modName,'/tmp/BACKUP_'..modName)
		printf(('Moved %s to %s'):format('ManagerMods/'..modName,'/tmp/BACKUP_'..modName))
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
	end
}
actions.r = actions.remove
actions.lf = actions.listfiles
actions.i = actions.install
actions.rmf = actions.registermoddedfile
actions.rmfl = actions.registermoddedfilelist
actions.l = actions.list
a = {}
for i in pairs(actions) do
	table.insert(a,i)
end
table.sort(a)
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
		printf('---------------\nSelected mod: %q, Selected action: %s\nCommands: %s',selection,cached_action,table.concat(a,', '))
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
	print(('%q is not a valid command\n valid commands:%s'):format(arg[1] or "",table.concat(a,', ')))
	return 
end
table.remove(arg,1)
action(table.unpack(arg))