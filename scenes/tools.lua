local log               = require("lib.log")
local pprint            = require("lib.pprint")
local scenes            = require("lib.scenes")
local skyscraper        = require("lib.skyscraper")
local channels          = require("lib.backend.channels")
local configs           = require("helpers.config")
local artwork           = require("helpers.artwork")
local utils             = require("helpers.utils")

local component         = require 'lib.gui.badr'
local popup             = require 'lib.gui.popup'
local listitem          = require 'lib.gui.listitem'
local scroll_container  = require 'lib.gui.scroll_container'
local output_log        = require 'lib.gui.output_log'

local tools             = {}
local theme             = configs.theme
local scraper_opts      = { "screenscraper", "thegamesdb" }
local scraper_index     = 1

local w_width, w_height = love.window.getMode()

local menu, info_window


local user_config, skyscraper_config = configs.user_config, configs.skyscraper_config
local finished_tasks = 0
local command_output = ""

local function dispatch_info(title, content)
  if title then info_window.title = title end
  if content then
    local scraping_log = info_window ^ "scraping_log"
    scraping_log.text = scraping_log.text .. "\n" .. content
  end
  info_window.visible = true
end

local function update_state()
  local t = channels.SKYSCRAPER_OUTPUT:pop()
  if t then
    -- if t.error and t.error ~= "" then
    --   dispatch_info("Error", t.error)
    -- end
    if t.data and next(t.data) then
      dispatch_info(string.format("Updating cache for %s, please wait...", t.data.platform))
    end
    if t.success ~= nil then
      finished_tasks = finished_tasks + 1
      dispatch_info(nil, string.format("Finished %d games", finished_tasks))
    end
    if t.command_finished then
      dispatch_info("Updated cache", "Cache has been updated.")
      finished_tasks = 0
      log.write("Cache updated successfully")
      artwork.process_cached_data()
    end
  end
end

local function update_task_state()
  local t = channels.TASK_OUTPUT:pop()
  if t then
    if t.error and t.error ~= "" then
      dispatch_info("Error", t.error)
    end
    if t.output and t.output ~= "" then
      command_output = command_output .. t.output .. "\n"
      local scraping_log = info_window ^ "scraping_log"
      scraping_log.text = command_output
    end
    if t.command_finished then
      if t.command == "backup" then
        dispatch_info("Backed up cache",
          "Cache has been backed up to SD2/ARCHIVE.\nYou can restore it using the muOS Archive Manager")
        log.write("Cache backed up successfully")
      elseif t.command == "migrate" then
        dispatch_info("Migrated cache", "Cache has been migrated to SD2.")
        skyscraper_config:insert("main", "cacheFolder", "\"/mnt/sdcard/scrappy_cache/\"")
        skyscraper_config:save()
        log.write("Cache migrated successfully")
      elseif t.command == "update_app" then
        dispatch_info("Updated Scrappy")
      end
    end
  end
end

local function on_refresh_press()
  user_config:load_platforms()
  user_config:save()
  dispatch_info("Refreshed platforms", "Platforms have been refreshed.")
end

local function on_update_press()
  log.write("Updating cache")
  local platforms = user_config:get().platforms
  local rom_path, _ = user_config:get_paths()

  dispatch_info("Updating cache", "Updating cache, please wait...")

  for src, dest in utils.orderedPairs(platforms or {}) do
    if dest ~= "unmapped" then
      local platform_path = string.format("%s/%s", rom_path, src)
      skyscraper.fetch_artwork(platform_path, src, dest)
    end
  end
end

local function on_import_press()
  log.write("Importing custom data")
  dispatch_info("Importing custom data", "Running import command...")
  local import_path = WORK_DIR .. "/static/.skyscraper/import"
  local lookup_folders = {}

  for _, item in ipairs(nativefs.getDirectoryItems(import_path) or {}) do
    local file_info = nativefs.getInfo(string.format("%s/%s", import_path, item))
    if file_info and file_info.type == "directory" then
      table.insert(lookup_folders, item)
    end
  end

  if #lookup_folders == 0 then
    log.write("Import Error: No folders to import")
    dispatch_info("Error", "Error: no folders to import.")
    return
  end

  local platforms = user_config:get().platforms
  local rom_path, _ = user_config:get_paths()

  local any_match = false

  for _, folder in ipairs(lookup_folders) do
    for src, dest in utils.orderedPairs(platforms or {}) do
      if folder == dest then
        any_match = true
        local platform_path = string.format("%s/%s", rom_path, src)
        skyscraper.custom_import(platform_path, dest)
      end
    end
  end

  if not any_match then
    log.write("No matching platforms found")
    dispatch_info("Error", "Error: No matching platforms found.")
    return
  end
end

local function on_change_scraper()
  local index = scraper_index + 1
  if index > #scraper_opts then index = 1 end
  local item = menu ^ "scraper_module"

  skyscraper.module = scraper_opts[index]
  scraper_index = index
  item.text = "Change Skyscraper module (current: " .. scraper_opts[scraper_index] .. ")"
end

local function on_reset_configs()
  user_config:start_fresh()
  skyscraper_config:start_fresh()
  dispatch_info("Configs reset", "Configs have been reset.")
end

local function on_backup_cache()
  log.write("Backing up cache to ARCHIVE folder")
  dispatch_info("Backing up cache to SD2/ARCHIVE folder", "Please wait...")
  local thread = love.thread.newThread("lib/backend/task_backend.lua")
  thread:start("backup")
end

local function on_migrate_cache()
  log.write("Migrating cache to SD2")
  dispatch_info("Migrating cache to SD2", "Please wait...")
  local thread = love.thread.newThread("lib/backend/task_backend.lua")
  thread:start("migrate")
end

local function on_app_update()
  log.write("Updating Scrappy")
  dispatch_info("Updating Scrappy", "Please wait...")
  local thread = love.thread.newThread("lib/backend/task_backend.lua")
  thread:start("update_app")
end

function tools:load()
  menu = component:root { column = true, gap = 10 }
  info_window = popup { visible = false }
  local item_width = w_width - 20

  menu = menu
      + (scroll_container {
          width = w_width,
          height = w_height - 60,
          scroll_speed = 30,
        }
        + (component { column = true, gap = 10 }
          -- TODO: Implement auto update
          + listitem {
            text = "Update Scrappy",
            width = item_width,
            onClick = on_app_update,
            icon = "download"
          }
          + listitem {
            text = "Migrate cache to SD2",
            width = item_width,
            onClick = on_migrate_cache,
            icon = "sd_card"
          }
          + listitem {
            text = "Backup cache to SD2/ARCHIVE folder",
            width = item_width,
            onClick = on_backup_cache,
            icon = "sd_card"
          }
          + listitem {
            id = "scraper_module",
            text = "Change Skyscraper module (current: " .. scraper_opts[scraper_index] .. ")",
            width = item_width,
            onClick = on_change_scraper,
            icon = "canvas"
          }
          + listitem {
            text = "Update cache (uses threads, doesn't generate artwork)",
            width = item_width,
            onClick = on_update_press,
            icon = "sd_card"
          }
          + listitem {
            text = "Run custom import (adds custom data to cache, read Wiki!)",
            width = item_width,
            onClick = on_import_press,
            icon = "file_import"
          }
          + listitem {
            text = "Rescan ROMs folders (overwrites [platforms] config)",
            width = item_width,
            onClick = on_refresh_press,
            icon = "folder"
          }
          + listitem {
            text = "Reset configs (can't be undone!)",
            width = item_width,
            onClick = on_reset_configs,
            icon = "refresh"
          }
        )
      )

  info_window = info_window
      + (
        component { column = true, gap = 15 }
        + output_log {
          visible = false,
          id = "scraping_log",
          width = info_window.width,
          height = w_height * 0.50,
        }
      )

  menu:updatePosition(10, 10)
  menu:focusFirstElement()
end

function tools:update(dt)
  menu:update(dt)
  update_state()
  update_task_state()
end

function tools:draw()
  love.graphics.clear(theme:read_color("main", "BACKGROUND", "#000000"))
  menu:draw()
  info_window:draw()
end

function tools:keypressed(key)
  menu:keypressed(key)
  if key == "escape" then
    if info_window.visible then
      info_window.visible = false
      -- Clear logs
      command_output = ""
      local scraping_log = info_window ^ "scraping_log"
      scraping_log.text = ""
    else
      scenes:pop()
    end
  end
end

return tools
