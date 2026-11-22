

-- Copyright (C) 2021, 2024 Sandro del Toro

-- This file is part of EmeraldShop Minetest Mod.

-- EmeraldShop is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as
-- published by the Free Software Foundation, either version 3 of the
-- License, or (at your option) any later version.

-- EmeraldShop is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.

-- You should have received a copy of the GNU Affero General Public License
-- along with EmeraldShop.  If not, see <https://www.gnu.org/licenses/>.


local S = core.get_translator(core.get_current_modname())

local shopcraft = core.settings:get_bool("emeraldshop.shop_craft") or false

-- privilege
core.register_privilege("admin_shop", {
   description = S("Enables the user to set regular vendors to admin vendors, or edit other players shops."),
   give_to_singleplayer = false,
})

emeraldbank.shop_timer = 5

local shop_timer = emeraldbank.shop_timer

local stock_h = 3
local stock_w = 5

local formspec_prefix = "emeraldshop:shop_formspec"

emeraldbank.player_inv =
   "list[current_player;main;0,4.5;9,3;9]"..
   mcl_formspec.get_itemslot_bg(0,4.5,9,3)..
   "list[current_player;main;0,7.74;9,1;]"..
   mcl_formspec.get_itemslot_bg(0,7.74,9,1)..
   "listring[current_player;main]"


function emeraldbank.get_shop_fs(pos, clicker)
   local meta = core.get_meta(pos)
   local count = meta:get_int("count")
   local price = meta:get_int("price")
   local shop_item = meta:get_string("shop_item")
   local list_name = "nodemeta:"..pos.x..','..pos.y..','..pos.z
   local pname = clicker:get_player_name()
   local owner = meta:get_string("owner")
   local player_press_key = clicker:get_player_control().aux1
   local shop_fs = ""
   local is_admin = core.check_player_privs(pname, {admin_shop=true})
   if (pname == owner or is_admin) and not player_press_key then
      shop_fs = "size[9,8.75]"..
	 "label[0,0;"..S("Your stock:").."]"..
	 "list["..list_name..";stock;0,0.5;"..stock_w..","..stock_h..";]"..
	 mcl_formspec.get_itemslot_bg(0,0.5,stock_w,stock_h)..
	 "field[6.5,2;2,1;count;"..S("Count")..";"..count.."]"..
	 "field[6.5,3;2,1;price;"..S("Price")..";"..price.."]"..
	 "label[6,0;"..S("In exchange, you give:").."]"..
	 "item_image[6.5,0.5;1,1;"..shop_item.."]"..
	 mcl_formspec.get_itemslot_bg(6.5,0.5,1,1)..
	 "label[0,4;"..S("Owner, Use (special key + right mouse button) for customer interface").."]"..
	 emeraldbank.player_inv
   else
      shop_fs = "size[9,8.75]"..
	 "label[3.7,0;"..S("Owner gives:").."]"..
	 "item_image[4,1;1,1;"..shop_item.."]"..
	 mcl_formspec.get_itemslot_bg(4,1,1,1)..
	 "label[5,1.5;"..S("x @1", count).."]"..
	 "label[4,2;"..S("Price: @1", price).."]"..
	 "button[3.5,3;2,1;exchange;"..S("Exchange").."]"..
	 emeraldbank.player_inv
   end
      
   return shop_fs

end


local function swap_shop(pos, closed)
   local oldnode = core.get_node(pos)
   local oldnodemeta = core.get_meta(pos):to_table()
   local nodename = core.get_node(pos).name
   if closed then
      core.swap_node(pos, {name = "emeraldshop:shop_empty"})
   else
      core.swap_node(pos, {name = "emeraldshop:shop"})
   end
   core.get_meta(pos):from_table(oldnodemeta)
end

local function set_item(pos, stack, player)
   local meta = core.get_meta(pos)
   local itemname = stack:get_name()
   local itemcount = stack:get_count()
   meta:set_string("shop_item", itemname)
   core.show_formspec(player:get_player_name(), formspec_prefix..core.pos_to_string(pos), emeraldbank.get_shop_fs(pos, player) )
end

local function check_empty(pos)
   local meta = core.get_meta(pos)
   local inv = meta:get_inventory()
   local count = meta:get_int("count")
   local shop_item = meta:get_string("shop_item")
   if inv:is_empty("stock") then
      meta:set_string("shop_item", "")
      swap_shop(pos, true)
   elseif not inv:contains_item("stock", shop_item.." "..count, true) then
      swap_shop(pos, true)
   else
      swap_shop(pos)
   end
end

local function after_place_node(pos, placer, itemstack)
   local owner = placer:get_player_name()
   local meta = core.get_meta(pos)
   meta:set_string("infotext", S("Exchange shop (owned by @1)", owner))
   meta:set_string("owner", owner)
   meta:set_int("count", 10) -- default count
   meta:set_int("price", 5) -- default price
   core.get_node_timer(pos):start(shop_timer)
   local inv = meta:get_inventory()
   inv:set_size("stock", stock_w*stock_h)
end

-- Compatibility guard: some EmeraldBank versions do not provide get_stonks.
local function safe_get_stonks(pos)
   if type(emeraldbank) == "table" and type(emeraldbank.get_stonks) == "function" then
      emeraldbank.get_stonks(pos)
   end
end

local function on_rightclick(pos, node, clicker, itemstack)
   local meta = core.get_meta(pos)
   local nodename = core.get_node(pos).name
   local owner = meta:get_string("owner")
   local pname = clicker:get_player_name()
   safe_get_stonks(pos)
   --if nodename == "emeraldshop:shop" or pname == owner then
   core.show_formspec(pname, formspec_prefix..core.pos_to_string(pos), emeraldbank.get_shop_fs(pos, clicker))
   --end
end

local function on_punch(pos, node, puncher, pointed_thing)
   safe_get_stonks(pos)
end

local function on_metadata_inventory_put(pos, listname, index, stack, player)
   set_item(pos, stack, player) -- this func already show the fs
   check_empty(pos)
end

local function on_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
   check_empty(pos)
   
end

local function on_metadata_inventory_take(pos, listname, index, stack, player)
   -- check_empty(pos) -- CRASH
   core.show_formspec(player:get_player_name(), formspec_prefix..core.pos_to_string(pos), emeraldbank.get_shop_fs(pos, player) )
end


local function on_timer(pos, elapsed)
   core.get_node_timer(pos):start(shop_timer)
   check_empty(pos)
   safe_get_stonks(pos)
end

local function can_dig(pos, player)
   local pname = player:get_player_name()
   local is_admin = core.check_player_privs(pname, {admin_shop=true})
   local meta = core.get_meta(pos)
   local owner = meta:get_string("owner")
   local inv = meta:get_inventory()
   return inv:is_empty("stock") and (pname == owner or is_admin)
end

-- register shop node
core.register_node("emeraldshop:shop", {
      description = S("Shop"),
      _doc_items_longdesc = S("A shop to sell your items with emeralds."),
      is_ground_content = false,
      tiles = {
	 "default_tree.png",
	 "default_tree.png",
	 "default_tree.png^mcl_core_emerald.png"
      },
      stack_max = 64,
      groups = {axey=1, handy=1, building_block=1},
      sounds = mcl_sounds.node_sound_wood_defaults(),
      _mcl_blast_resistance = 5,
      _mcl_hardness = 1,
      
      after_place_node = after_place_node,
      on_rightclick = on_rightclick,
      on_punch = on_punch,
      on_metadata_inventory_put = on_metadata_inventory_put,
      on_metadata_inventory_move = on_metadata_inventory_move,
      on_metadata_inventory_take = on_metadata_inventory_take,
      on_timer = on_timer,
      can_dig = can_dig
})

-- register shop node
core.register_node("emeraldshop:shop_empty", {
      description = S("Shop Empty"),
      _doc_items_longdesc = S("A shop to sell your items with emeralds."),
      is_ground_content = false,
      tiles = {
	 "default_tree.png",
	 "default_tree.png",
	 "default_tree.png^mcl_core_emerald.png^mcl_core_barrier.png"
      },
      stack_max = 64,
      groups = {axey=1, handy=1, building_block=1, not_in_creative_inventory=1},
      sounds = mcl_sounds.node_sound_wood_defaults(),
      drop = "emeraldshop:shop",
      _mcl_blast_resistance = 5,
      _mcl_hardness = 1,
      
      after_place_node = after_place_node,
      on_rightclick = on_rightclick,
      on_punch = on_punch,
      on_metadata_inventory_put = on_metadata_inventory_put,
      on_metadata_inventory_move = on_metadata_inventory_move,
      on_metadata_inventory_take = on_metadata_inventory_take,
      on_timer = on_timer,
      can_dig = can_dig
})


core.register_on_player_receive_fields(function(sender, formname, fields)
      local prefix_len = string.len(formspec_prefix)
      if formname:sub(1,prefix_len) == formspec_prefix then
	 
	 local pos_string = formname:sub(prefix_len+1)
	 local pos = core.string_to_pos(pos_string)
	 local meta = core.get_meta(pos)
	 local name = sender:get_player_name()
	 local playermeta = sender:get_meta()
	 local player_pos = sender:get_pos()
	 local old_count = meta:get_int("count")
	 local new_count = tonumber(fields.count)
	 local old_price = meta:get_int("price")
	 local new_price = tonumber(fields.price)
	 local shop_item = meta:get_string("shop_item")
	 local minv = meta:get_inventory()
	 local pinv = sender:get_inventory()
	 atm.read_account(name)
	 local bankemeralds = atm.balance[name]

	 -- set or reset timer
	 core.get_node_timer(pos):start(shop_timer)

	 -- set item count
	 if fields.count and string.find(fields.count, "^[0-9]+$") then
	    if new_count >= 1 and new_count <= 64 and new_count ~= meta:get_int("count") then
	       meta:set_int("count", new_count)
	       check_empty(pos)
	    end
	 end

	 -- set price
	 if fields.price and string.find(fields.price, "^[0-9]+$") then
	    if new_price >= 1 and new_price <= 10000 and new_price ~= meta:get_int("price") then
	       meta:set_int("price", new_price)
	    end
	 end

	 -- someone hit exchange button
	 if fields.exchange ~= nil and fields.exchange ~= "" then

	    -- owner try exchanges
	    if meta:get_string("owner") == name then
	       core.chat_send_player(name, S("This is your own shop, you can't exchange to yourself!"))

	    else
	       
	       local can_exchange = true

	       -- have u money?
	       if bankemeralds < old_price then
		  can_exchange = false
		  core.chat_send_player(name, S("Not enough Emeralds in your account"))
	       end

	       --there are enough items?
	       if not minv:contains_item("stock", shop_item.." "..old_count, true) then
		  can_exchange = false
		  core.chat_send_player(name, S("Out of Stock!"))
	       end

	       -- do not trade air
	       if shop_item == "" or shop_item == "air" then
		  can_exchange = false
	       end
	       
	       if can_exchange then
		  minv:remove_item("stock", shop_item.." "..old_count)
		  core.add_item(player_pos, shop_item.." "..old_count)
		  emeraldbank.add_emeralds(sender, -old_price)
		  meta:set_int("stonks", meta:get_int("stonks")+old_price)
		  mcl_title.set(sender, "subtitle", {text=S("Exchanged!"), color="green"})
		  check_empty(pos)
		  core.show_formspec(sender:get_player_name(), formspec_prefix..core.pos_to_string(pos), emeraldbank.get_shop_fs(pos, sender) )
	       end
	       
	    end
	    
	 end
	 
      end      
end)


if shopcraft then
   core.register_craft({
	 output = "emeraldshop:shop 3",
	 recipe = {
	    {"mcl_core:emerald", "mcl_core:emerald", "mcl_core:emerald"},
	    {"mcl_core:emerald", "mcl_core:tree", "mcl_core:emerald"},
	    {"mcl_core:emerald", "mcl_core:emerald", "mcl_core:emerald"},
	 }
   })
end
