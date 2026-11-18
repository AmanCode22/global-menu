--!nonstrict
-- hud.luau - HUD-style search of the focused application's menus
--
-- A launcher provider: type its prefix (default /hud) in the launcher, or
-- bind a key to `noctalia msg panel-toggle launcher /hud`. Every enabled
-- item of the focused application's menus becomes one row that reads like
-- the menu itself ("File › Export   (Ctrl+E)"), so any item can be found by
-- typing a few letters of it. Choosing a row sends the same activate
-- command the popup panel uses.
--
-- The menu tree comes from the "menu" state key, which the service keeps
-- current for the focused window; this entry never talks to D-Bus itself.
-- Labels arrive without mnemonic markers and accelerators arrive
-- formatted (accelLabel), so the HUD and the panel always agree.

local SEP = " › "
local MAX_RESULTS = 200

-- ---------------------------------------------------------------- helpers

local function postCommand(body)
    local port = tonumber(noctalia.state.get("port"))
    if port == nil then return end
    noctalia.http({
        url = "http://127.0.0.1:" .. tostring(port) .. "/cmd",
        method = "POST",
        headers = {
            "Content-Type: application/json",
            "X-GlobalMenu-Token: " .. tostring(noctalia.state.get("token") or ""),
        },
        body = noctalia.json.encode(body),
    }, function() end)
end

-- every enabled leaf of the tree, in menu order
local function flatten(nodes, path, out)
    for _, node in ipairs(nodes or {}) do
        if type(node) == "table" and node.separator ~= true and
                node.enabled ~= false then
            local label = noctalia.string.trim(tostring(node.label or ""))
            if type(node.children) == "table" and #node.children > 0 then
                local sub = table.clone(path)
                if label ~= "" then table.insert(sub, label) end
                flatten(node.children, sub, out)
            elseif label ~= "" then
                table.insert(out, {
                    label = label,
                    path = table.concat(path, SEP),
                    key = tostring(node.key or node.label or ""),
                    accel = node.accelLabel,
                    checked = node.toggleState == true and
                            node.toggleType ~= nil and node.toggleType ~= "",
                })
            end
        end
    end
    return out
end

-- every word of the query must appear in the label or the path; matches
-- in the label rank above matches only in the path
local function score(item, words, query)
    local label = item.label:lower()
    local hay = label .. " " .. item.path:lower()
    for _, word in ipairs(words) do
        if hay:find(word, 1, true) == nil then return nil end
    end
    if query == "" then return 0 end
    if label:sub(1, #query) == query then return 3 end
    if label:find(query, 1, true) then return 2 end
    if label:find(words[1], 1, true) then return 1 end
    return 0
end

local function message(query, title, subtitle)
    launcher.setResults(query, { {
        id = "", title = title, subtitle = subtitle, glyph = "menu-2",
    } })
end

-- ---------------------------------------------------------------- launcher

function onQuery(query)
    local menu = noctalia.state.get("menu")
    local app = type(menu) == "table" and (menu.appName or menu.app) or nil
    if type(menu) ~= "table" or type(menu.tree) ~= "table" or
            menu.source == nil or menu.source == "none" then
        message(query, "No menu for this window", app)
        return
    end

    local text = noctalia.string.trim(query):lower()
    local words = {}
    for word in text:gmatch("%S+") do table.insert(words, word) end

    local matches = {}
    for index, item in ipairs(flatten(menu.tree, {}, {})) do
        local s = score(item, words, text)
        if s ~= nil then
            table.insert(matches, { item = item, score = s, order = index })
        end
    end
    -- stable: best score first, then menu order
    table.sort(matches, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.order < b.order
    end)

    local rows = {}
    for i, match in ipairs(matches) do
        if i > MAX_RESULTS then break end
        local item = match.item
        -- one line, the way the menu reads: "File › Export   (Ctrl+E)"
        local title = item.path ~= "" and (item.path .. SEP .. item.label)
                or item.label
        if item.checked then title = "✓ " .. title end
        if item.accel ~= nil then
            title = title .. "   (" .. item.accel .. ")"
        end
        -- the activation key itself is the row id, so a re-query while
        -- the launcher is open can never shift which item runs
        table.insert(rows, {
            id = item.key,
            title = title,
            icon = menu.app,
            glyph = "menu-2",
        })
    end
    if #rows == 0 then
        message(query, "No matching menu item", app)
        return
    end
    launcher.setResults(query, rows)
end

function onActivate(id)
    if id ~= nil and id ~= "" then
        postCommand({ cmd = "activate", key = id })
    end
end
