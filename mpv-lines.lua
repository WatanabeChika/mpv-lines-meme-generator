-- Original by Wanakachi
-- Suitable for Windows operating systems

-- Create long graph of lines with mpv
-- Requires ffmpeg.
-- Usage: "n" to screenshot (can be pressed repeatedly), "Ctrl+n" to create.

require "mp.options"
local utils = require "mp.utils"

local options = {
    dir = "YOUR_PATH_HERE", -- Your path to save screenshots
    height = 0.15,  -- Height of the lines to keep (starting from the bottom)
    lossless = false,  -- Use lossless screenshots
}

read_options(options, "line-shot")

local timestamp = os.date("%Y%m%d_%H%M%S")
local screenshot_dir = options.dir
local screenshot_format = options.lossless and ".png" or ".jpg"
local screenshot_count = 0
local screenshots = {}

-- Take and crop screenshots
function take_screenshot()
    screenshot_count = screenshot_count + 1

    -- Take original shots
    local screenshot_file = utils.join_path(screenshot_dir, "temp_screenshot_" .. screenshot_count .. screenshot_format)
    mp.commandv("screenshot-to-file", screenshot_file, "subtitles")

    -- Crop the shots (except the first one)
    local processed_file = utils.join_path(screenshot_dir, string.format("line_shot_%03d" .. screenshot_format, screenshot_count))
    local crop_arg = ""

    if screenshot_count > 1 then
        crop_arg = "crop=iw:ih*" .. options.height .. ":0:ih*" .. (1 - options.height)
    else
        crop_arg = "crop=iw:ih:0:0"
    end

    -- Use ffmpeg to crop the shots 
    local crop_command = {"ffmpeg", "-i", screenshot_file, "-vf", crop_arg, processed_file}

    local result = utils.subprocess({args = crop_command})
    if result.status == 0 then
        mp.osd_message("Shot saved: " .. processed_file)
        table.insert(screenshots, processed_file)
    else
        mp.osd_message("Cropping failed: " .. result.error)
    end

    -- Delete the original shots
    os.remove(screenshot_file)
end

-- Stitch the cropped screenshots together
function stitch_images()
    if #screenshots <= 1 then
        mp.osd_message("No shots to stitch!")
        return
    end

    local command = {"ffmpeg", "-y"}
    local output_file = utils.join_path(screenshot_dir, "stitched_screenshot_" .. timestamp .. screenshot_format)
    local filter_expr = "vstack=" .. #screenshots

    -- Add input files, filter, output filename, one by one
    for i = 1, #screenshots do
        table.insert(command, "-i")
        table.insert(command, screenshots[i])
    end
    table.insert(command, "-filter_complex")
    table.insert(command, filter_expr)
    table.insert(command, output_file)

    -- Run the command
    local result = utils.subprocess({args = command})

    if result.status == 0 then
        mp.osd_message("Stitched shot saved: " .. output_file)
    else
        mp.osd_message("Stitching failed: " .. result.error)
        return
    end

    -- Delete the cropped shots and reset the counter
    for _, img in ipairs(screenshots) do
        os.remove(img)
    end

    screenshots = {}
    screenshot_count = 0
end

-- Bindings
mp.add_key_binding("n", "take-screenshot", take_screenshot)
mp.add_key_binding("Ctrl+n", "stitch-images", stitch_images)
