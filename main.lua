--[[
	select md5,count(*) from files group by md5 having count(*) > 1

	select * from files where md5=='0722da1b8fb3667a02eb8cfcc690aed0'
]]
--[[
 todo : faire une interface Web pour gérer les doublons, l'état du systèmes et lancer le service de calcul MD5
 creationix/weblit via https://github.com/creationix/weblit
]]

local bundle = require('luvi').bundle
loadstring(bundle.readfile("luvit-loader.lua"), "bundle:luvit-loader.lua")()

local sql = require "sqlite3"

local uv = require("uv")
local openssl    = require'openssl' -- ssl inclus avec luvi
local io = require("io")

function dirtree(dir)
  assert(dir and dir ~= "", "directory parameter is missing or empty")
  if string.sub(dir, -1) == "/" then
    dir=string.sub(dir, 1, -2)
  end

  local function yieldtree(dir)
	local req = uv.fs_scandir(dir)
	if not req then
		return
	end
	local function iter()
	  return uv.fs_scandir_next(req)
	end
    for entry,ftype in iter do      -- ftype is nil on unix, but ok on windows
        entry=dir.."/"..entry
        local size = 0
        
		local stat, err, code = uv.fs_stat(entry)
		if not ftype then	
			ftype = stat.type
		end	
		size = stat.size
		
				
		coroutine.yield(entry,ftype,size)
		if ftype == "directory" then
		  yieldtree(entry)
		end      
    end
  end

  return coroutine.wrap(function() yieldtree(dir) end)
end



function compute_checksum(filename)
	md = openssl.digest.get('md5')
	mdc=md:new()
	
	local f = assert(io.open(filename, "rb"))
    local block = 1024 * 2 -- *512
    while true do
      local bytes = f:read(block)
      if not bytes then break end     
	  mdc:update(bytes)	  
    end
	f:close()
	
	
	bb = mdc:final()
	return bb
end

function initDb(file)
	local conn = sql.open(file)	
	conn:exec[[
	CREATE TABLE files( fullpath TEXT PRIMARY KEY,md5 TEXT, filesize INTEGER);	
	]]

	return conn
end




function isFileInDb(conn,stmt,file) 
	local x= stmt:reset():bind(file):step()	
	return (x~=nil)
end

function insertInDb(conn,insert_stmt,filename,md5,size)
	insert_stmt:reset():bind(filename,md5,size):step()		
end

function initOrLoadDB(file)		
	-- check if db file exists
	local stat, err, code = uv.fs_stat(file)
	if stat and stat.type ~= 'file' then -- no, it's a directory : bad !
		error(" db file : "..file.."exists but it is not a file")
	end 
	
	local conn
	if not stat then
		conn = initDb(file)		
	else
		conn = sql.open(file)	
	end
	
	
	local select_stmt = conn:prepare("select 1 from  files where fullpath == ?")
	local insert_stmt = conn:prepare("insert into files values (?,?,?)")
	
	return conn,select_stmt,insert_stmt
end




if args[1] == nil or args[2] == nil then
	print("usage : ",args[0],"repertoire fichier_db")
	print("ou bien avec luvi : ./luvi-regular-xxx appli -- repertoire fichier_db")
else
	local conn,select_stmt,insert_stmt = initOrLoadDB(args[2])
	
 -- todo : test if args[1] is a directory or file : if simple file then don't call dirtree but compute_checksum only
 -- here we assume args[1] is a directory
	for filename, ftype,size in dirtree(args[1]) do
		-- print(ftype, filename)
		if ftype == 'file' then
			-- todo : if file in db don't compute md5, pass it
			if not isFileInDb(conn,select_stmt,filename)	then
			    io.write(string.format("process %s, size : %f MB", filename,size/1024/1024) )
			    io.flush()
				local md5 = compute_checksum(filename)
				io.write(string.format(" md5 is  %s", md5) )
				-- print(md5,filename,size)
				io.write("\n")
				insertInDb(conn,insert_stmt,filename,md5,size)
			end
			-- todo : insert in db
		end	
		
	end
end
