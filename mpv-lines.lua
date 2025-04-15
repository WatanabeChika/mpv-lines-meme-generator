-- original by wanakachi
-- suitable for windows operating systems

-- create long graph of lines with mpv
-- requires ffmpeg.
-- usage: "n" to screenshot (can be pressed repeatedly), "ctrl+n" to create.

require("mp.options")
local utils = require("mp.utils")

-- 在options中添加bottom_margin和loglevel选项
local options = {
	dir = "/home/djl/Pictures/mpv-long-shots/", -- your path to save screenshots
	height = 0.15,                           -- height of the lines to keep (starting from the bottom)
	bottom_margin = 0,                       -- 字幕下边界距离视频底部的距离
	lossless = false,                        -- use lossless screenshots
	ffmpeg_loglevel = "error",               -- ffmpeg日志级别: quiet, panic, fatal, error, warning, info, verbose, debug
}

read_options(options, "line-shot")

local timestamp = os.date("%y%m%d_%h%m%s")
local screenshot_dir = options.dir
local screenshot_format = options.lossless and ".png" or ".jpg"
local screenshot_count = 0
local screenshots = {}

-- take and crop screenshots
function take_screenshot()
	screenshot_count = screenshot_count + 1

	-- take original shots
	local screenshot_file = utils.join_path(screenshot_dir, "temp_screenshot_" .. screenshot_count .. screenshot_format)
	mp.commandv("screenshot-to-file", screenshot_file, "subtitles")

	-- crop the shots
	local processed_file =
		utils.join_path(screenshot_dir, string.format("line_shot_%03d" .. screenshot_format, screenshot_count))
	local crop_arg = ""

	if screenshot_count > 1 then
		-- 第2张及以后应用上下边界
		local effective_height = options.height - options.bottom_margin
		local start_y = (1 - options.height)
		crop_arg = "crop=iw:ih*" .. effective_height .. ":0:ih*" .. start_y
	else
		-- 第1张只应用底部边距
		local effective_height = 1 - options.bottom_margin -- 保留从顶部到bottom_margin的部分
		crop_arg = "crop=iw:ih*" .. effective_height .. ":0:0" -- 从顶部开始裁剪
	end

	-- use ffmpeg to crop the shots (quietly)
	local crop_command =
	{ "ffmpeg", "-loglevel", options.ffmpeg_loglevel, "-i", screenshot_file, "-vf", crop_arg, "-y", processed_file }

	local result = utils.subprocess({ args = crop_command })
	if result.status == 0 then
		mp.osd_message("shot saved: " .. processed_file)
		table.insert(screenshots, processed_file)
	else
		mp.osd_message("cropping failed: " .. result.error)
	end

	-- delete the original shots
	os.remove(screenshot_file)
end

-- stitch the cropped screenshots together
function stitch_images()
	if #screenshots <= 1 then
		mp.osd_message("no shots to stitch!")
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
		mp.osd_message("stitched shot saved: " .. output_file)
	else
		mp.osd_message("stitching failed: " .. result.error)
		return
	end

	-- delete the cropped shots and reset the counter
	for _, img in ipairs(screenshots) do
		os.remove(img)
	end

	screenshots = {}
	screenshot_count = 0
end

-- bindings
mp.add_key_binding("n", "take-screenshot", take_screenshot)
mp.add_key_binding("ctrl+n", "stitch-images", stitch_images)
-- 动态调整参数功能 (添加在脚本末尾)

-- 调整参数函数
function increase_height()
	options.height = math.min(options.height + 0.01, 0.5)
	mp.osd_message(string.format("字幕高度: %.2f", options.height))
end

function decrease_height()
	options.height = math.max(options.height - 0.01, options.bottom_margin)
	mp.osd_message(string.format("字幕高度: %.2f", options.height))
end

function increase_bottom_margin()
	options.bottom_margin = math.min(options.bottom_margin + 0.01, options.height)
	mp.osd_message(string.format("下边距: %.2f", options.bottom_margin))
end

function decrease_bottom_margin()
	options.bottom_margin = math.max(options.bottom_margin - 0.01, 0)
	mp.osd_message(string.format("下边距: %.2f", options.bottom_margin))
end

-- 绑定快捷键
mp.add_key_binding("Alt+up", "increase-height", increase_height)
mp.add_key_binding("Alt+down", "decrease-height", decrease_height)
mp.add_key_binding("Alt+right", "increase-bottom-margin", increase_bottom_margin)
mp.add_key_binding("Alt+left", "decrease-bottom-margin", decrease_bottom_margin)
-- 鼠标位置比例显示功能
local mouse_pos_overlay = nil
local showing_mouse_pos = false
local mouse_timer = nil

function show_mouse_position(x, y)
	if not mouse_pos_overlay then
		mouse_pos_overlay = mp.create_osd_overlay("ass-events")
	end

	-- 获取视频和窗口尺寸
	local osd_width, osd_height = mp.get_osd_size()
	local video_width = mp.get_property_number("width", 0)
	local video_height = mp.get_property_number("height", 0)

	if video_width == 0 or video_height == 0 or osd_width == 0 or osd_height == 0 then
		return
	end

	-- 计算视频在窗口中的尺寸和位置
	local scale = math.min(osd_width / video_width, osd_height / video_height)
	local scaled_width = video_width * scale
	local scaled_height = video_height * scale
	local video_x = (osd_width - scaled_width) / 2
	local video_y = (osd_height - scaled_height) / 2

	-- 检查鼠标是否在视频区域内
	if x < video_x or x > video_x + scaled_width or y < video_y or y > video_y + scaled_height then
		-- 鼠标在视频外，显示提示信息
		mouse_pos_overlay.data = "{\\an7\\pos(10,10)\\fs20\\bord1}鼠标不在视频区域内"
		mouse_pos_overlay:update()
		return
	end

	-- 将鼠标坐标转换为视频内相对坐标
	local rel_x = (x - video_x) / scaled_width
	local rel_y = (y - video_y) / scaled_height

	-- 计算距离底部的比例
	local bottom_ratio = 1 - rel_y

	-- 仅在左上角显示比例信息
	local text_style = "{\\an7\\pos(10,10)\\fs20\\bord1}"
	local text = string.format("%s距底部: %.2f (位置: %.0f, %.0f)", text_style, bottom_ratio, x, y)
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
		mp.osd_message("鼠标位置比例显示已启用")
	else
		if mouse_pos_overlay then
			mouse_pos_overlay:remove()
		end
		if mouse_timer then
			mouse_timer:kill()
		end
		mp.osd_message("鼠标位置比例显示已禁用")
	end
end

-- 绑定快捷键
mp.add_key_binding("Alt+m", "toggle-mouse-position", toggle_mouse_pos)
