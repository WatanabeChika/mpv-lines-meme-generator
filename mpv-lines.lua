-- original by Wanakachi
-- suitable for Windows operating systems

-- create long graph of lines with mpv
-- requires ffmpeg.
-- usage: "n" to screenshot (can be pressed repeatedly), "Ctrl+n" to create.
--        "Alt+up/down/right/left" to adjust the top/bottom margin of the subtitles.
--        "Alt+m" to toggle the mouse position ratio display.

require("mp.options")
local utils = require("mp.utils")

local options = {
	dir = "C:/Users/26063/Pictures/screenshots",  -- your path to save screenshots
	subtitle_top = 0.15,                          -- distance (ratio) from the top of the video to the top margin of subtitles
	subtitle_bottom = 0,                          -- distance (ratio) from the bottom of the video to the bottom margin of subtitles
	lossless = false,                             -- use lossless screenshots
	ffmpeg_loglevel = "error",                    -- ffmpeg log level: quiet, panic, fatal, error, warning, info, verbose, debug
}

read_options(options, "line-shot")

local timestamp = os.date("%y%m%d_%h%m%s")
local screenshot_dir = options.dir
local screenshot_format = options.lossless and ".png" or ".jpg"
local screenshot_count = 0
local screenshots = {}

local mouse_pos_overlay = nil
local showing_mouse_pos = false
local mouse_timer = nil

-- take and crop screenshots
function take_screenshot()
    -- Check if the directory exists
    if not utils.file_info(screenshot_dir) then
        mp.osd_message("Directory does not exist: " .. screenshot_dir)
        return
    end

	screenshot_count = screenshot_count + 1

	-- take original shots
	local screenshot_file = utils.join_path(screenshot_dir, "temp_screenshot_" .. screenshot_count .. screenshot_format)
	mp.commandv("screenshot-to-file", screenshot_file, "subtitles")

	-- crop the shots
	local processed_file =
		utils.join_path(screenshot_dir, string.format("line_shot_%03d" .. screenshot_format, screenshot_count))
	local crop_arg = ""

	if screenshot_count > 1 then
		-- apply top and bottom margins for the second and subsequent screenshots
		local effective_subtitle_top = options.subtitle_top - options.subtitle_bottom
		local start_y = (1 - options.subtitle_top)
		crop_arg = "crop=iw:ih*" .. effective_subtitle_top .. ":0:ih*" .. start_y
	else
		-- apply only the bottom margin for the first screenshot
		local effective_subtitle_top = 1 - options.subtitle_bottom
		crop_arg = "crop=iw:ih*" .. effective_subtitle_top .. ":0:0"
	end

	-- use ffmpeg to crop the shots (quietly)
	local crop_command =
	{ "ffmpeg", "-loglevel", options.ffmpeg_loglevel, "-i", screenshot_file, "-vf", crop_arg, "-y", processed_file }

	local result = utils.subprocess({ args = crop_command })
	if result.status == 0 then
		mp.osd_message("Shot saved: " .. processed_file)
		table.insert(screenshots, processed_file)
	else
		mp.osd_message("Cropping failed: " .. result.error)
	end

	-- delete the original shots
	os.remove(screenshot_file)
end

-- stitch the cropped screenshots together
function stitch_images()
	if #screenshots <= 1 then
		mp.osd_message("No shots to stitch!")
		return
	end

	local command = { "ffmpeg", "-loglevel", options.ffmpeg_loglevel, "-y" }
	local output_file = utils.join_path(screenshot_dir, "stitched_screenshot_" .. timestamp .. screenshot_format)
	local filter_expr = "vstack=" .. #screenshots

	-- add input files, filter, output filename, one by one
	for i = 1, #screenshots do
		table.insert(command, "-i")
		table.insert(command, screenshots[i])
	end
	table.insert(command, "-filter_complex")
	table.insert(command, filter_expr)
	table.insert(command, output_file)

	-- run the command
	local result = utils.subprocess({ args = command })

	if result.status == 0 then
		mp.osd_message("Stitched shot saved: " .. output_file)
	else
		mp.osd_message("Stitching failed: " .. result.error)
		return
	end

	-- delete the cropped shots and reset the counter
	for _, img in ipairs(screenshots) do
		os.remove(img)
	end

	screenshots = {}
	screenshot_count = 0
end

-- mouse position ratio display functionality
function show_mouse_position(x, y)
	if not mouse_pos_overlay then
		mouse_pos_overlay = mp.create_osd_overlay("ass-events")
	end

	-- get video and window dimensions
	local osd_width, osd_height = mp.get_osd_size()
	local video_width = mp.get_property_number("width", 0)
	local video_height = mp.get_property_number("height", 0)

	if video_width == 0 or video_height == 0 or osd_width == 0 or osd_height == 0 then
		return
	end

	-- calculate the size and position of the video in the window
	local scale = math.min(osd_width / video_width, osd_height / video_height)
	local scaled_width = video_width * scale
	local scaled_height = video_height * scale
	local video_x = (osd_width - scaled_width) / 2
	local video_y = (osd_height - scaled_height) / 2

	-- check if the mouse is within the video area
	if x < video_x or x > video_x + scaled_width or y < video_y or y > video_y + scaled_height then
		mouse_pos_overlay.data = "{\\an7\\pos(10,10)\\fs20\\bord1}Mouse is outside the video area"
		mouse_pos_overlay:update()
		return
	end

	-- convert mouse coordinates to relative coordinates within the video
	local rel_x = (x - video_x) / scaled_width
	local rel_y = (y - video_y) / scaled_height

	-- calculate the ratio from the bottom
	local bottom_ratio = 1 - rel_y

	-- display the ratio information in the top-left corner only
	local text_style = "{\\an7\\pos(10,10)\\fs20\\bord1}"
	local text = string.format("%sDistance from bottom: %.2f (Position: %.0f, %.0f)", text_style, bottom_ratio, x, y)
	mouse_pos_overlay.data = text
	mouse_pos_overlay:update()
end

function toggle_mouse_pos()
	showing_mouse_pos = not showing_mouse_pos

	if showing_mouse_pos then
		mouse_timer = mp.add_periodic_timer(0.1, function()
			local mx, my = mp.get_mouse_pos()
			show_mouse_position(mx, my)
		end)
		mp.osd_message("Mouse position ratio display enabled")
	else
		if mouse_pos_overlay then
			mouse_pos_overlay:remove()
		end
		if mouse_timer then
			mouse_timer:kill()
		end
		mp.osd_message("Mouse position ratio display disabled")
	end
end

-- parameter adjustment functions
function increase_subtitle_top()
	options.subtitle_top = math.min(options.subtitle_top + 0.01, 0.5)
	mp.osd_message(string.format("Top margin: %.2f", options.subtitle_top))
end

function decrease_subtitle_top()
	options.subtitle_top = math.max(options.subtitle_top - 0.01, options.subtitle_bottom)
	mp.osd_message(string.format("Top margin: %.2f", options.subtitle_top))
end

function increase_subtitle_bottom()
	options.subtitle_bottom = math.min(options.subtitle_bottom + 0.01, options.subtitle_top)
	mp.osd_message(string.format("Bottom margin: %.2f", options.subtitle_bottom))
end

function decrease_subtitle_bottom()
	options.subtitle_bottom = math.max(options.subtitle_bottom - 0.01, 0)
	mp.osd_message(string.format("Bottom margin: %.2f", options.subtitle_bottom))
end

-- bindings
mp.add_key_binding("n", "take-screenshot", take_screenshot)
mp.add_key_binding("Ctrl+n", "stitch-images", stitch_images)

mp.add_key_binding("Alt+m", "toggle-mouse-position", toggle_mouse_pos)

mp.add_key_binding("Alt+up", "increase-subtitle-top", increase_subtitle_top, {repeatable = true})
mp.add_key_binding("Alt+down", "decrease-subtitle-top", decrease_subtitle_top, {repeatable = true})
mp.add_key_binding("Alt+right", "increase-subtitle-bottom", increase_subtitle_bottom, {repeatable = true})
mp.add_key_binding("Alt+left", "decrease-subtitle-bottom", decrease_subtitle_bottom, {repeatable = true})
