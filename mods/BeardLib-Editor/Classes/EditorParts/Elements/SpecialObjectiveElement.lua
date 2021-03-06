EditorSpecialObjective = EditorSpecialObjective or class(MissionScriptEditor)
EditorSpecialObjective.INSTANCE_VAR_NAMES = {
	{
		type = "special_objective_action",
		value = "so_action"
	}
}
EditorSpecialObjective._AI_SO_types = {
	"AI_defend",
	"AI_security",
	"AI_hunt",
	"AI_search",
	"AI_idle",
	"AI_escort",
	"AI_sniper",
	"AI_phalanx"
}
function EditorSpecialObjective:init(unit)
	EditorSpecialObjective.super.init(self, unit)
	self._enemies = {}
	self._nav_link_filter = {}
	self._nav_link_filter_check_boxes = {}	
end
function EditorSpecialObjective:create_element()
	self.super.create_element(self)
	self._element.class = "ElementSpecialObjective"
	self._element.values.ai_group = "none"
	self._element.values.align_rotation = true
	self._element.values.align_position = true
	self._element.values.needs_pos_rsrv = true
	self._element.values.scan = true
	self._element.values.patrol_path = "none"
	self._element.values.path_style = "none"
	self._element.values.path_haste = "none"
	self._element.values.path_stance = "none"
	self._element.values.pose = "none"
	self._element.values.so_action = "none"
	self._element.values.search_position =  Vector3(0,0,0)
	self._element.values.search_distance = 0
	self._element.values.interval = ElementSpecialObjective._DEFAULT_VALUES.interval
	self._element.values.base_chance = ElementSpecialObjective._DEFAULT_VALUES.base_chance
	self._element.values.chance_inc = 0
	self._element.values.action_duration_min = ElementSpecialObjective._DEFAULT_VALUES.action_duration_min
	self._element.values.action_duration_max = ElementSpecialObjective._DEFAULT_VALUES.action_duration_max
	self._element.values.interrupt_dis = 7
	self._element.values.interrupt_dmg = ElementSpecialObjective._DEFAULT_VALUES.interrupt_dmg
	self._element.values.attitude = "none"
	self._element.values.trigger_on = "none"
	self._element.values.interaction_voice = "none"
	self._element.values.SO_access = "0"
	self._element.values.test_unit = "default"	
end
function EditorSpecialObjective:post_init(...)
	EditorSpecialObjective.super.post_init(self, ...)
	self._nav_link_filter = managers.navigation:convert_access_filter_to_table(self._element.values.SO_access)
	if type_name(self._element.values.SO_access) == "number" then
		self._element.values.SO_access = tostring(self._element.values.SO_access)
	end
end
function EditorSpecialObjective:test_element()
	if not managers.navigation:is_data_ready() then
	 	BeardLibEditor:log("Can't test spawn unit without ready navigation data (AI-graph)")
		return
	end
	local spawn_unit_name
	if self._element.values.test_unit == "default" then
		local SO_access_strings = managers.navigation:convert_access_filter_to_table(self._element.values.SO_access)
		for _, access_category in ipairs(SO_access_strings) do
			if access_category == "civ_male" then
				spawn_unit_name = Idstring("units/payday2/characters/civ_male_casual_1/civ_male_casual_1")
				break
			elseif access_category == "civ_female" then
				spawn_unit_name = Idstring("units/payday2/characters/civ_female_casual_1/civ_female_casual_1")
				break
			elseif access_category == "spooc" then
				spawn_unit_name = Idstring("units/payday2/characters/ene_spook_1/ene_spook_1")
				break
			elseif access_category == "shield" then
				spawn_unit_name = Idstring("units/payday2/characters/ene_shield_2/ene_shield_2")
				break
			elseif access_category == "tank" then
				spawn_unit_name = Idstring("units/payday2/characters/ene_bulldozer_1/ene_bulldozer_1")
				break
			elseif access_category == "taser" then
				spawn_unit_name = Idstring("units/payday2/characters/ene_tazer_1/ene_tazer_1")
				break
			else
				spawn_unit_name = Idstring("units/payday2/characters/ene_swat_1/ene_swat_1")
				break
			end
		end
	else
		spawn_unit_name = self._element.values.test_unit
	end
	spawn_unit_name = spawn_unit_name or Idstring("units/payday2/characters/ene_swat_1/ene_swat_1")
	local enemy = safe_spawn_unit(spawn_unit_name, self._unit:position(), self._unit:rotation())
	if not enemy then
		return
	end
	table.insert(self._enemies, enemy)
	managers.groupai:state():set_char_team(enemy, tweak_data.levels:get_default_team_ID("non_combatant"))
	enemy:movement():set_root_blend(false)
	local t = {
		id = self._unit:unit_data().unit_id,
		editor_name = self._unit:unit_data().name_id
	}
	t.values = self:new_save_values()
	t.values.use_instigator = true
	t.values.is_navigation_link = false
	t.values.followup_elements = nil
	t.values.trigger_on = "none"
	t.values.spawn_instigator_ids = nil
	self._script = MissionScript:new({
		elements = {}
	})
	self._so_class = ElementSpecialObjective:new(self._script, t)
	self._so_class._values.align_position = nil
	self._so_class._values.align_rotation = nil
	self._so_class:on_executed(enemy)
	self._start_test_t = Application:time()
end
function EditorSpecialObjective:stop_test_element()
	for _, enemy in ipairs(self._enemies) do
		enemy:set_slot(0)
	end
	self._enemies = {}
	print("Stop test time", self._start_test_t and Application:time() - self._start_test_t or 0)
end
function EditorSpecialObjective:draw_links(t, dt, selected_unit, all_units)
	EditorSpecialObjective.super.draw_links(self, t, dt, selected_unit)
	self:_draw_follow_up(selected_unit, all_units)
end
function EditorSpecialObjective:update_selected(t, dt, selected_unit, all_units)
	if self._element.values.patrol_path ~= "none" then
		managers.editor:layer("Ai"):draw_patrol_path_externaly(self._element.values.patrol_path)
	end
	local brush = Draw:brush()
	brush:set_color(Color(0.15, 1, 1, 1))
	local pen = Draw:pen(Color(0.15, 0.5, 0.5, 0.5))
	brush:sphere(self._element.values.search_position, self._element.values.search_distance, 4)
	pen:sphere(self._element.values.search_position, self._element.values.search_distance)
	brush:sphere(self._element.values.search_position, 10, 4)
	Application:draw_line(self._element.values.search_position, self._unit:position(), 0, 1, 0)
	self:_draw_follow_up(selected_unit, all_units)
	if self._element.values.spawn_instigator_ids then
		for _, id in ipairs(self._element.values.spawn_instigator_ids) do
			local unit = all_units[id]
			local draw = not selected_unit or unit == selected_unit or self._unit == selected_unit
			if draw then
				self:_draw_link({
					from_unit = unit,
					to_unit = self._unit,
					r = 0,
					g = 0,
					b = 0.75
				})
			end
		end
	end
	self:_highlight_if_outside_the_nav_field(t)
end
function EditorSpecialObjective:_highlight_if_outside_the_nav_field(t)
	if managers.navigation:is_data_ready() then
		local my_pos = self._unit:position()
		local nav_tracker = managers.navigation._quad_field:create_nav_tracker(my_pos, true)
		if nav_tracker:lost() then
			local t1 = t % 0.5
			local t2 = t % 1
			local alpha
			if t2 > 0.5 then
				alpha = t1
			else
				alpha = 0.5 - t1
			end
			alpha = math.lerp(0.1, 0.5, alpha)
			local nav_color = Color(alpha, 1, 0, 0)
			Draw:brush(nav_color):cylinder(my_pos, my_pos + math.UP * 80, 20, 4)
		end
		managers.navigation:destroy_nav_tracker(nav_tracker)
	end
end
function EditorSpecialObjective:update_unselected(t, dt, selected_unit, all_units)
	if self._element.values.followup_elements then
		local followup_elements = self._element.values.followup_elements
		local i = #followup_elements
		while i > 0 do
			local element_id = followup_elements[i]
			if not alive(all_units[element_id]) then
				table.remove(followup_elements, i)
			end
			i = i - 1
		end
		if not next(followup_elements) then
			self._element.values.followup_elements = nil
		end
	end
	if self._element.values.spawn_instigator_ids then
		local spawn_instigator_ids = self._element.values.spawn_instigator_ids
		local i = #spawn_instigator_ids
		while i > 0 do
			local id = spawn_instigator_ids[i]
			if not alive(all_units[id]) then
				table.remove(self._element.values.spawn_instigator_ids, i)
			end
			i = i - 1
		end
		if not next(spawn_instigator_ids) then
			self._element.values.spawn_instigator_ids = nil
		end
	end
end
function EditorSpecialObjective:_draw_follow_up(selected_unit, all_units)
	if self._element.values.followup_elements then
		for _, element_id in ipairs(self._element.values.followup_elements) do
			local unit = all_units[element_id]
			local draw = not selected_unit or unit == selected_unit or self._unit == selected_unit
			if draw then
				self:_draw_link({
					from_unit = self._unit,
					to_unit = unit,
					r = 0,
					g = 0.75,
					b = 0
				})
			end
		end
	end
end
function EditorSpecialObjective:update_editing()
	self:_so_raycast()
	self:_spawn_raycast()
	self:_raycast()
end
function EditorSpecialObjective:_so_raycast()
	local ray = managers.editor:unit_by_raycast({mask = 10, ray_type = "editor"})
	if ray and ray.unit and (string.find(ray.unit:name():s(), "point_special_objective", 1, true) or string.find(ray.unit:name():s(), "ai_so_group", 1, true)) then
		local id = ray.unit:unit_data().unit_id
		Application:draw(ray.unit, 0, 1, 0)
		return id
	end
	return nil
end
function EditorSpecialObjective:_spawn_raycast()
	local ray = managers.editor:unit_by_raycast({mask = 10, ray_type = "editor"})
	if not ray or not ray.unit then
		return
	end
	local id
	if string.find(ray.unit:name():s(), "ai_enemy_group", 1, true) or string.find(ray.unit:name():s(), "ai_spawn_enemy", 1, true) or string.find(ray.unit:name():s(), "ai_civilian_group", 1, true) or string.find(ray.unit:name():s(), "ai_spawn_civilian", 1, true) then
		id = ray.unit:unit_data().unit_id
		Application:draw(ray.unit, 0, 0, 1)
	end
	return id
end
function EditorSpecialObjective:_raycast()
	local from = managers.editor:get_cursor_look_point(0)
	local to = managers.editor:get_cursor_look_point(100000)
	local ray = World:raycast(from, to, nil, managers.slot:get_mask("all"))
	if ray and ray.position then
		Application:draw_sphere(ray.position, 10, 1, 1, 1)
		return ray.position
	end
	return nil
end
function EditorSpecialObjective:_lmb()
	local id = self:_so_raycast()
	if id then
		if self._element.values.followup_elements then
			for i, element_id in ipairs(self._element.values.followup_elements) do
				if element_id == id then
					table.remove(self._element.values.followup_elements, i)
					if not next(self._element.values.followup_elements) then
						self._element.values.followup_elements = nil
					end
					return
				end
			end
		end
		self._element.values.followup_elements = self._element.values.followup_elements or {}
		table.insert(self._element.values.followup_elements, id)
		return
	end
	local id = self:_spawn_raycast()
	if id then
		if self._element.values.spawn_instigator_ids then
			for i, si_id in ipairs(self._element.values.spawn_instigator_ids) do
				if si_id == id then
					table.remove(self._element.values.spawn_instigator_ids, i)
					if not next(self._element.values.spawn_instigator_ids) then
						self._element.values.spawn_instigator_ids = nil
					end
					return
				end
			end
		end
		self._element.values.spawn_instigator_ids = self._element.values.spawn_instigator_ids or {}
		table.insert(self._element.values.spawn_instigator_ids, id)
		return
	end
	self._element.values.search_position = self:_raycast() or self._element.values.search_position
end
function EditorSpecialObjective:add_triggers(vc)
	vc:add_trigger(Idstring("lmb"), callback(self, self, "_lmb"))
end
function EditorSpecialObjective:selected()
	EditorSpecialObjective.super.selected(self)
	if not managers.ai_data:patrol_path(self._element.values.patrol_path) then
		self._element.values.patrol_path = "none"
	end
	CoreEws.update_combobox_options(self._patrol_path_params, table.list_add({"none"}, managers.ai_data:patrol_path_names()))
	CoreEws.change_combobox_value(self._patrol_path_params, self._element.values.patrol_path)
end
function EditorSpecialObjective:_apply_preset(menu, item)
	QuickMenu:new( "Special objective", "Apply preset " .. (item.selected or "")  .. "?", {[1] = {text = "Yes", callback = function()	
		if item.selected == "clear" then
			self:_clear_all_nav_link_filters()
		elseif item.selected == "all" then
			self:_enable_all_nav_link_filters()
		else		
			log(item.selected)

		end 	
	end},[2] = {text = "No", is_cancel_button = true}}, true)
end
function EditorSpecialObjective:_enable_all_nav_link_filters()
	for  k, check in pairs(self._nav_link_filter_check_boxes) do
		check:SetValue(true)
		self:_toggle_nav_link_filter_value(check)
	end
end
function EditorSpecialObjective:_clear_all_nav_link_filters()
	for  k, check in pairs(self._nav_link_filter_check_boxes) do
		check:SetValue(false)
		self:_toggle_nav_link_filter_value(check)
	end
end
function EditorSpecialObjective:_toggle_nav_link_filter_value(item)
	if item.value then
		for i, k in ipairs(self._nav_link_filter) do
			if k == item.name then
				return
			end
		end
		table.insert(self._nav_link_filter, item.name)
	else
		table.delete(self._nav_link_filter, item.name)
	end
	self._element.values.SO_access = managers.navigation:convert_access_filter_to_string(self._nav_link_filter)
end
function EditorSpecialObjective:_build_panel()
	self:_create_panel()
	self._nav_link_filter_check_boxes = self._nav_link_filter_check_boxes or {}

	self._nav_link_filter = managers.navigation:convert_access_filter_to_table(self._element.values.SO_access)
	self._elements_menu:ComboBox({
		name = "preset",
		text = "Preset:",
		items = {"clear", "all"},
		help = "Select a preset.",		
		callback = callback(self, self, "_apply_preset"),
	})
	local opt = NavigationManager.ACCESS_FLAGS
	for i, o in ipairs(opt) do
		local check = self._elements_menu:Toggle({
			name = o,
			text = o,
			value = table.contains(self._nav_link_filter, o),
			callback = callback(self, self, "_toggle_nav_link_filter_value"),
		})	
		table.insert(self._nav_link_filter_check_boxes, check)
	end
	self:_build_value_combobox("ai_group", table.list_add({"none"}, clone(ElementSpecialObjective._AI_GROUPS)), "Select an ai group.")
	self:_build_value_checkbox("is_navigation_link", "", nil, "Navigation link")
	self:_build_value_checkbox("align_rotation", "Align rotation")
	self:_build_value_checkbox("align_position", "Align position")
	self:_build_value_checkbox("needs_pos_rsrv", "", nil, "Reserve position")
	self:_build_value_checkbox("repeatable", "Repeatable")
	self:_build_value_checkbox("use_instigator", "Use instigator")
	self:_build_value_checkbox("forced", "Forced")
	self:_build_value_checkbox("no_arrest", "No Arrest")
	self:_build_value_checkbox("scan", "Idle scan", nil, "Idle scan")
	self:_build_value_checkbox("allow_followup_self", "", nil, "Allow self-followup")
	self:_build_value_number("search_distance", {min = 0}, "Used to specify the distance to use when searching for an AI")
	local options = table.list_add({"none"}, clone(CopActionAct._act_redirects.SO))
	self:_build_value_combobox("so_action", table.list_add(options, self._AI_SO_types), "Select a action that the unit should start with.")
	local ctrlr, params = self:_build_value_combobox("patrol_path", table.list_add({"none"}, {} --[[managers.ai_data:patrol_path_names()]]), "Select a patrol path to use from the spawn point. Different objectives and behaviors will interpet the path different.")
	self._patrol_path_params = params
	self:_build_value_combobox("path_style", table.list_add({"none"}, ElementSpecialObjective._PATHING_STYLES), "Specifies how the patrol path should be used.")
	self:_build_value_combobox("path_haste", table.list_add({"none"}, ElementSpecialObjective._HASTES), "Select path haste to use.")
	self:_build_value_combobox("path_stance", table.list_add({"none"}, ElementSpecialObjective._STANCES), "Select path stance to use.")
	self:_build_value_combobox("pose", table.list_add({"none"}, ElementSpecialObjective._POSES), "Select pose to use.")
	self:_build_value_combobox("attitude", table.list_add({"none"}, ElementSpecialObjective._ATTITUDES), "Select combat attitude.")
	self:_build_value_combobox("trigger_on", table.list_add({"none"}, ElementSpecialObjective._TRIGGER_ON), "Select when to trigger objective.")
	self:_build_value_combobox("interaction_voice", table.list_add({"none"}, ElementSpecialObjective._INTERACTION_VOICES), "Select what voice to use when interacting with the character.")
	self:_build_value_number("interrupt_dis", {min = -1}, "Interrupt if a threat is detected closer than this distance (meters). -1 means at any distance. For non-visible threats this value is multiplied with 0.7.", nil, "Interrupt Distance:")
	self:_build_value_number("interrupt_dmg", {min = -1}, "Interrupt if total damage received as a ratio of total health exceeds this ratio. value: 0-1.", nil, "Interrupt Damage:")
	self:_build_value_number("interval", {min = -1}, "Used to specify how often the SO should search for an actor. A negative value means it will check only once.")
	self:_build_value_number("base_chance", {
		min = 0,
		max = 1
	}, "Used to specify chance to happen (1==absolutely!)")
	self:_build_value_number("chance_inc", {
		min = 0,
		max = 1
	}, "Used to specify an incremental chance to happen", nil, "Chance incremental:")
	self:_build_value_number("action_duration_min", {min = 0}, "How long the character stays in his specified action.")
	self:_build_value_number("action_duration_max", {min = 0}, "How long the character stays in his specified action. Zero means indefinitely.")
	local test_units = table.list_add(EditorSpawnCivilian._options, EditorSpawnEnemyDummy._options)
	table.insert(test_units, 1, "default")
--	self:_build_value_combobox("test_unit", test_units, "Select the unit to be used when testing.")
end
 