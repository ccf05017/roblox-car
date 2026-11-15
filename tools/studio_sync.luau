local Http = game:GetService("HttpService")
local PYTHON_HTTP_SERVER = "http://127.0.0.1:34877/"

local SUFFIXES = {
	{ suffix = ".server.luau", class = "Script" },
	{ suffix = ".client.luau", class = "LocalScript" },
	{ suffix = ".luau", class = "ModuleScript" },
}

local function classify(file: string): (string?, string?)
	for _, rule in SUFFIXES do
		if string.sub(file, -#rule.suffix) == rule.suffix then
			return string.sub(file, 1, -#rule.suffix - 1), rule.class
		end
	end
	return nil, nil
end

local log = {}

local function listEntries(path: string): ({ string }, { string })
	local listing = Http:GetAsync(PYTHON_HTTP_SERVER .. path .. "/")
	local files, folders = {}, {}
	for file in string.gmatch(listing, 'href="([^"/]+)"') do
		table.insert(files, file)
	end
	for folder in string.gmatch(listing, 'href="([^"/]+)/"') do
		table.insert(folders, folder)
	end
	return files, folders
end

local function syncFolder(target: Instance, path: string)
	local wanted = {}
	local files, folders = listEntries(path)
	for _, name in folders do
		wanted[name] = true
		local existing = target:FindFirstChild(name)
		if existing and not existing:IsA("Folder") then
			existing:Destroy()
			existing = nil
		end
		local folder = existing or Instance.new("Folder")
		folder.Name = name
		folder.Parent = target
		syncFolder(folder, path .. "/" .. name)
	end
	for _, file in files do
		local name, class = classify(file)
		if name then
			wanted[name] = true
			local existing = target:FindFirstChild(name)
			if existing and existing.ClassName ~= class then
				existing:Destroy()
				existing = nil
			end
			local script = existing or Instance.new(class :: string)
			script.Name = name
			script.Source = Http:GetAsync(PYTHON_HTTP_SERVER .. path .. "/" .. file)
			script.Parent = target
			table.insert(log, "sync " .. path .. "/" .. file)
		end
	end
	for _, child in target:GetChildren() do
		if (child:IsA("LuaSourceContainer") or child:IsA("Folder")) and not wanted[child.Name] then
			table.insert(log, "remove " .. child:GetFullName())
			child:Destroy()
		end
	end
end

local function walk(node: { [string]: any }, instance: Instance)
	if node["$path"] then
		syncFolder(instance, node["$path"])
	end
	for key, child in node do
		if string.sub(key, 1, 1) ~= "$" then
			local found = if instance == game then game:GetService(key) else instance:FindFirstChild(key)
			if not found then
				found = Instance.new("Folder")
				found.Name = key
				found.Parent = instance
			end
			walk(child, found)
		end
	end
end

walk(Http:JSONDecode(Http:GetAsync(PYTHON_HTTP_SERVER .. "default.project.json")).tree, game)
return table.concat(log, "\n")
