require("globals")

local json              = require("lib.json")
local log               = require("lib.log")
local channels          = require("lib.backend.channels")
local skyscraper_config = require("helpers.config").skyscraper_config

local skyscraper        = {
  base_command = "./Skyscraper",
  module = "screenscraper",
  config_path = "",
  peas_json = {}
}

local cache_thread, gen_thread

local function push_cache_command(command)
  if channels.SKYSCRAPER_INPUT then
    channels.SKYSCRAPER_INPUT:push(command)
  end
end
local function push_command(command)
  if channels.SKYSCRAPER_GEN_INPUT then
    channels.SKYSCRAPER_GEN_INPUT:push(command)
  end
end

function skyscraper.init(config_path, binary)
  log.write("Initializing Skyscraper")
  skyscraper.config_path = WORK_DIR .. "/" .. config_path
  skyscraper.base_command = "./" .. binary

  -- Create threads for cache and generate commands
  cache_thread = love.thread.newThread("lib/backend/skyscraper_backend.lua")
  gen_thread = love.thread.newThread("lib/backend/skyscraper_generate_backend.lua")

  -- Load peas.json file
  local peas_file = nativefs.read(string.format("%s/static/.skyscraper/peas.json", WORK_DIR))
  if peas_file then
    skyscraper.peas_json = json.decode(peas_file)
  else
    log.write("Unable to load peas.json file")
  end

  cache_thread:start()
  gen_thread:start()
  push_cache_command({ command = string.format("%s -v", skyscraper.base_command) })
end

function skyscraper.filename_matches_extension(filename, platform)
  local formats = skyscraper.peas_json[platform] and skyscraper.peas_json[platform].formats
  if not formats then
    log.write("Unable to determine file formats for platform " .. platform)
    return true
  end

  -- .zip and .7z are added by default
  -- https://gemba.github.io/skyscraper/PLATFORMS/#sample-usecase-adding-platform-satellaview
  local match_patterns = { '%.*%.zip$', '%.*%.7z$' }
  -- Convert patterns to Lua-compatible patterns
  for _, pattern in ipairs(formats) do
    local lua_pattern = pattern:gsub("%*", ".*"):gsub("%.", "%%.")
    -- Add '$' to ensure the pattern matches the end of the string
    lua_pattern = lua_pattern .. "$"
    table.insert(match_patterns, lua_pattern)
  end

  -- Check if a file matches any of the patterns
  for _, pattern in ipairs(match_patterns) do
    if filename:match(pattern) then
      return true
    end
  end

  return false
end

local function generate_command(config)
  if config.fetch == nil then
    config.fetch = false
  end
  if config.use_config == nil then
    config.use_config = true
  end
  if config.module == nil then
    config.module = skyscraper.module
  end

  local command = ""
  if config.platform then
    command = string.format('%s -p %s', command, config.platform)
  end
  if config.fetch then
    command = string.format('%s -s %s', command, config.module)
  end
  if config.use_config then
    command = string.format('%s -c "%s"', command, skyscraper.config_path)
  end
  if config.cache then
    command = string.format('%s -d "%s"', command, config.cache)
  end
  if config.input then
    command = string.format('%s -i "%s"', command, config.input)
  end
  if config.rom then
    command = string.format('%s --startat "%s" --endat "%s"', command, config.rom, config.rom)
  end
  if config.artwork then
    command = string.format('%s -a "%s"', command, config.artwork)
  end
  if config.flags and next(config.flags) then
    command = string.format('%s --flags %s', command, table.concat(config.flags, ","))
  end

  -- Force maximum number of threads
  command = string.format('%s -t 8', command)
  -- Use 'pegasus' frontend for simpler gamelist generation
  command = string.format('%s -f pegasus', command)
  return command
end

function skyscraper.run(command, input_folder, platform, op, game)
  platform = platform or "none"
  op = op or "generate"
  game = game or "none"
  if op == "generate" then
    push_command({
      command = skyscraper.base_command .. command,
      platform = platform,
      op = op,
      game = game,
      input_folder = input_folder,
    })
  else
    push_cache_command({
      command = skyscraper.base_command .. command,
      platform = platform,
      op = op,
      game = game,
      input_folder = input_folder,
    })
  end
end

function skyscraper.change_artwork(artworkXml)
  skyscraper_config:insert("main", "artworkXml", '"' .. artworkXml .. '"')
  skyscraper_config:save()
end

function skyscraper.update_sample(artwork_path)
  local command = generate_command({
    use_config = false,
    platform = "megadrive",
    cache = WORK_DIR .. "/sample",
    input = WORK_DIR .. "/sample",
    artwork = artwork_path,
    flags = { "unattend" },
  })
  skyscraper.run(command, "N/A", "N/A", "generate", "fake-rom")
end

function skyscraper.custom_update_artwork(platform, cache, input, artwork)
  local command = generate_command({
    use_config = false,
    platform = platform,
    cache = cache,
    input = input,
    artwork = artwork,
    flags = { "unattend" },
  })
  skyscraper.run(command)
end

function skyscraper.fetch_artwork(rom_path, input_folder, platform)
  local command = generate_command({
    platform = platform,
    input = rom_path,
    fetch = true,
    flags = { "unattend", "onlymissing" },
  })
  skyscraper.run(command, input_folder, platform, "update")
end

function skyscraper.update_artwork(rom_path, rom, input_folder, platform, artwork)
  local artwork = WORK_DIR .. "/templates/" .. artwork .. ".xml"
  local update_command = generate_command({
    platform = platform,
    input = rom_path,
    artwork = artwork,
    rom = rom,
  })
  skyscraper.run(update_command, input_folder, platform, "generate", rom)
end

function skyscraper.fetch_single(rom_path, rom, input_folder, platform, ...)
  local flags = select(1, ...) or { "unattend" }
  local fetch_command = generate_command({
    platform = platform,
    input = rom_path,
    fetch = true,
    rom = rom,
    flags = flags,
  })
  skyscraper.run(fetch_command, input_folder, platform, "fetch", rom)
end

function skyscraper.custom_import(rom_path, platform)
  local command = generate_command({
    platform = platform,
    input = rom_path,
    module = "import",
    fetch = true,
  })
  skyscraper.run(command, "N/A", platform, "import")
end

return skyscraper
