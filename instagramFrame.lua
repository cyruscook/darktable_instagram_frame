--[[
		Licensed under the GNU General Public License v3.
]]
--[[

USAGE
* require this script from your luarc file
	To do this add this line to the file .config/darktable/luarc: 
require "instagramFrame"
]]

local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("7.0.0", "instagramFramer") 

-- return data structure for script_manager

local script_data = {}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- translation

-- https://www.darktable.org/lua-api/index.html#darktable_gettext
local gettext = dt.gettext

gettext.bindtextdomain("instagramFramer", dt.configuration.config_dir .. "/lua/locale/")

local function _(msgid)
		return gettext.dgettext("instagramFramer", msgid)
end

-- declare a local namespace and a couple of variables we'll need to install the module
local mE = {}
mE.event_registered = false	-- keep track of whether we've added an event callback or not
mE.module_installed = false	-- keep track of whether the module is module_installed

--[[ We have to create the module in one of two ways depending on which view darktable starts
		 in.	In orker to not repeat code, we wrap the darktable.register_lib in a local function.
	]]

local function get_style (style_name)
	local styles = dt.styles
	local style = nil
	for _, s in ipairs(styles) do
		if s.name == style_name then
			style = s
		end
	end
	return style
end

local function apply_one_image (image)
	aspect = image.final_width / image.final_height
	if aspect > 1.91 then
		dt.styles.apply(get_style("insta_big_frame"),image)
	end
	if aspect < 0.8 then
		dt.styles.apply(get_style("insta_small_frame"),image)
	end
end

local function install_module()
	if not mE.module_installed then
		-- https://www.darktable.org/lua-api/index.html#darktable_register_lib
		dt.register_lib(
			"instagramFramerModule",		 -- Module name
			"instagramFramerModule",		 -- name
			true,								-- expandable
			true,							 -- resetable
			{[dt.gui.views.darkroom] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},	 -- containers
			-- https://www.darktable.org/lua-api/types_lua_box.html
			dt.new_widget("box") -- widget
			{
				orientation = "vertical",
				dt.new_widget("button")
				{
					label = _("Enable"),
					clicked_callback = function (_)
						local images = dt.gui.action_images
						for _,image in pairs(images) do
							apply_one_image(image)
						end
					end
				},
		reset_callback = function()
			dt.print(_("Reset"))
		end,
			},
			nil,-- view_enter
			nil -- view_leave
		)
		mE.module_installed = true
	end
end

-- script_manager integration to allow a script to be removed
-- without restarting darktable
local function destroy()
		dt.gui.libs["instagramFramerModule"].visible = false -- we haven't figured out how to destroy it yet, so we hide it for now
end

local function restart()
		dt.gui.libs["instagramFramerModule"].visible = true -- the user wants to use it again, so we just make it visible and it shows up in the UI
end


-- ... and tell dt about it all


if dt.gui.current_view().id == "lighttable" then -- make sure we are in darkroom view
	install_module()	-- register the lib
else
	if not mE.event_registered then -- if we are not in darkroom view then register an event to signal when we might be
		-- https://www.darktable.org/lua-api/index.html#darktable_register_event
		dt.register_event(
			"IF_ViewChanged", "view-changed",	-- we want to be informed when the view changes
			function(event, old_view, new_view)
				if new_view.name == "lighttable" and old_view.name == "darkroom" then	-- if the view changes from lighttable to darkroom
					install_module()	-- register the lib
				 end
			end
		)
		mE.event_registered = true	--	keep track of whether we have an event handler installed
	end
end

-- set the destroy routine so that script_manager can call it when
-- it's time to destroy the script and then return the data to 
-- script_manager
script_data.destroy = destroy
script_data.restart = restart	-- only required for lib modules until we figure out how to destroy them
script_data.destroy_method = "hide" -- tell script_manager that we are hiding the lib so it knows to use the restart function
script_data.show = restart	-- if the script was "off" when darktable exited, the module is hidden, so force it to show on start

return script_data