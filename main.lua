local uv = require("uv")
local openssl    = require'openssl' -- ssl inclus avec luvi


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
		if not ftype then -- use fs_stat for unix
			local stat, err, code = uv.fs_stat(entry)
			ftype = stat.type
		end
				
		coroutine.yield(entry,ftype)
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

function initOrLoadDB(file)
	-- todo : if file is not found : create it on create table
	-- if exists : open it
	return nil
end

if args[1] == nil or args[2] == nil then
	print("usage : ",args[0],"repertoire fichier_db")
	print("ou bien avec luvi : ./luvi-regular-xxx appli -- repertoire fichier_db")
else
	local db = nil	
	db = initOrLoadDB(args[2])
	
 -- todo : test if args[1] is a directory or file : if simple file then don't call dirtree but compute_checksum only
 -- here we assume args[1] is a directory
	for filename, ftype in dirtree(args[1]) do
		-- print(ftype, filename)
		if ftype == 'file' then
			-- todo : if file in db don't compute md5, pass it
			local md5 = compute_checksum(filename)
			print(md5,filename)
			-- todo : insert in db
		end	
		
	end
end
