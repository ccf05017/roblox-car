-- Rojo-less one-shot sync for agents driving Studio through MCP, where nobody can press the Rojo plugin's Connect button.
-- Serve the repo with `python3 -m http.server 34877 --bind 127.0.0.1`, then run this file in Studio's Edit DataModel.
-- Mirrors each `$path` folder in default.project.json using Rojo's file-name rules, and removes scripts whose file is gone.
local Http = game:GetService("HttpService")
local BASE = "http://127.0.0.1:34877/"

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

local function syncFolder(target: Instance, path: string)
	local listing = Http:GetAsync(BASE .. path .. "/")
	local wanted = {}
	for file in string.gmatch(listing, 'href="([^"/]+)"') do
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
			script.Source = Http:GetAsync(BASE .. path .. "/" .. file)
			script.Parent = target
			table.insert(log, "sync " .. path .. "/" .. file)
		end
	end
	for _, child in target:GetChildren() do
		if child:IsA("LuaSourceContainer") and not wanted[child.Name] then
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

walk(Http:JSONDecode(Http:GetAsync(BASE .. "default.project.json")).tree, game)
return table.concat(log, "\n")
