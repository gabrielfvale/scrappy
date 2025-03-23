require("globals")

local parser = {}
local line_patterns = {
  "found!",
  "Skipping game",
  "not found",
  "match too low",
  "No entries to scrape..."
}
local game_title_patterns = {
  FOUND = "Game '(.-)' found!",
  NOT_FOUND = "Game '(.-)' not found",
  MATCH_TOO_LOW = "Game '(.-)' match too low",
  SKIPPED = "Skipping game '(.-)' since"
}
local log_patterns = {
  "Running Skyscraper v",
  "Fetching limits for user",
  "Starting scraping run",
  "Resource gathering run"
}
local return_types = {
  GAME = "game",
  LOG = "log",
}

--[[
  Parse a line of Skyscraper output, returning:
  - A line to be logged, or a game title if found
  - An error message if the line is an error
  - A boolean indicating whether the game is skipped or not
  - A string indicating the return type
--]]
function parser.parse(line)
  local game_pattern = "'([^']*'.-)'"
  local line_match = nil

  for _, pattern in ipairs(log_patterns) do
    if line:find(pattern) then
      return line, nil, false, return_types.LOG
    end
  end

  for _, pattern in ipairs(line_patterns) do
    if line:find(pattern) then
      line_match = pattern
      break
    end
  end

  if line_match then
    -- print("Line matched: " .. line)
    -- Extract game title
    if line_match == line_patterns[1] then -- Found
      local game_title = string.match(line, game_title_patterns.FOUND)
      return game_title, nil, false, return_types.GAME
    elseif line_match == line_patterns[2] then -- Skipped
      local game_title = string.match(line, game_title_patterns.SKIPPED)
      return game_title, nil, false, return_types.GAME
    elseif line_match == line_patterns[3] then -- Not found
      local game_title = string.match(line, game_title_patterns.NOT_FOUND)
      return game_title, nil, true, return_types.GAME
	elseif line_match == line_patterns[4] then -- Match too low
      local game_title = string.match(line, game_title_patterns.MATCH_TOO_LOW)
      return game_title, nil, true, return_types.GAME
    end
    return "N/A", nil, true, return_types.GAME
  else
    -- print("Line did not match: " .. line)
    for _, error in ipairs(SKYSCRAPER_ERRORS) do
      if line:find(error) then
        return nil, line, true, return_types.LOG
      end
    end
    return nil, nil, nil
  end
end

return parser
