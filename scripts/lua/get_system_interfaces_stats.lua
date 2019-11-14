--
-- (C) 2019 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local format_utils = require("format_utils")
local json = require("dkjson")

sendHTTPContentTypeHeader('application/json')

-- ################################################

local currentPage  = _GET["currentPage"]
local perPage      = _GET["perPage"]
local sortColumn   = _GET["sortColumn"]
local sortOrder    = _GET["sortOrder"]

local sortPrefs = "system_interfaces_data"

-- ################################################

if isEmptyString(sortColumn) or sortColumn == "column_" then
   sortColumn = getDefaultTableSort(sortPrefs)
else
   if((sortColumn ~= "column_")
      and (sortColumn ~= "")) then
      tablePreferences("sort_"..sortPrefs, sortColumn)
   end
end

if isEmptyString(_GET["sortColumn"]) then
   sortOrder = getDefaultTableSortOrder(sortPrefs, true)
end

if((_GET["sortColumn"] ~= "column_")
   and (_GET["sortColumn"] ~= "")) then
   tablePreferences("sort_order_"..sortPrefs, sortOrder, true)
end

if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
   perPage = tonumber(perPage)
   tablePreferences("rows_number", perPage)
end

local sOrder = ternary(sortOrder == "asc", asc_insensitive, rev_insensitive)
local to_skip = (currentPage-1) * perPage

-- ################################################

local ifaces_stats = {}

for _, iface in pairs(interface.getIfNames()) do
   interface.select(iface)
   ifaces_stats[iface] = interface.getStats()
end

local totalRows = 0
local sort_to_key = {}

for iface, ifstats in pairs(ifaces_stats) do
   if(sortColumn == "column_engaged_alerts") then
      sort_to_key[iface] = ifstats.num_alerts_engaged
   elseif(sortColumn == "column_alerted_flows") then
      sort_to_key[iface] = ifstats.num_alerted_flows
   elseif(sortColumn == "column_local_hosts") then
      sort_to_key[iface] = ifstats.stats.local_hosts
   elseif(sortColumn == "column_remote_hosts") then
      sort_to_key[iface] = ifstats.stats.hosts
   elseif(sortColumn == "column_devices") then
      sort_to_key[iface] = ifstats.stats.devices
   elseif(sortColumn == "column_flows") then
      sort_to_key[iface] = ifstats.stats.flows
   elseif(sortColumn == "column_traffic") then
      sort_to_key[iface] = ifstats.stats_since_reset.bytes
   elseif(sortColumn == "column_packets") then
      sort_to_key[iface] = ifstats.stats_since_reset.packets
   elseif(sortColumn == "column_drops") then
      sort_to_key[iface] = ifstats.stats_since_reset.drops
   elseif(sortColumn == "column_name") then
      sort_to_key[iface] = getInterfaceName(ifstats.id)
   else
      sort_to_key[iface] = ifstats.id
   end

   totalRows = totalRows + 1
   ::continue::
end

-- ################################################

local res = {}
local i = 0

for key in pairsByValues(sort_to_key, sOrder) do
   if i >= to_skip + perPage then
      break
   end

   if i >= to_skip then
      local record = {}
      local ifstats = ifaces_stats[key]
      local remote_hosts = ifstats.stats.hosts - ifstats.stats.local_hosts
      local drops_pct = round(ifstats.stats_since_reset.drops / (ifstats.stats_since_reset.drops + ifstats.stats_since_reset.packets) * 100, 2)

      record["column_ifid"] = string.format("%i", ifstats.id)
      record["column_engaged_alerts"] = ternary(ifstats.num_alerts_engaged > 0, format_utils.formatValue(ifstats.num_alerts_engaged), '')
      record["column_alerted_flows"] = ternary(ifstats.num_alerted_flows > 0, format_utils.formatValue(ifstats.num_alerted_flows), '')
      record["column_local_hosts"] = ternary(ifstats.stats.local_hosts > 0, format_utils.formatValue(ifstats.stats.local_hosts), '')
      record["column_remote_hosts"] = ternary(remote_hosts > 0, format_utils.formatValue(remote_hosts), '')
      record["column_devices"] = ternary(ifstats.stats.devices > 0, format_utils.formatValue(ifstats.stats.devices), '')
      record["column_flows"] = ternary(ifstats.stats.flows > 0, format_utils.formatValue(ifstats.stats.flows), '')
      record["column_traffic"] = ternary(ifstats.stats_since_reset.bytes > 0, format_utils.bytesToSize(ifstats.stats_since_reset.bytes), '')
      record["column_packets"] = ternary(ifstats.stats_since_reset.packets > 0, format_utils.formatPackets(ifstats.stats_since_reset.packets), '')
      record["column_drops"] = ternary(ifstats.stats_since_reset.drops > 0, format_utils.formatPackets(ifstats.stats_since_reset.drops), '')
      record["column_name"] = getInterfaceName(ifstats.id)

      res[#res + 1] = record
   end

   i = i + 1
end

-- ################################################

local result = {}
result["perPage"] = perPage
result["currentPage"] = currentPage
result["totalRows"] = totalRows
result["data"] = res
result["sort"] = {{sortColumn, sortOrder}}

print(json.encode(result))