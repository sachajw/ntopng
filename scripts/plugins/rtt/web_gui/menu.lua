return {
  label = "host_config.rtt_monitor",
  script = "rtt_stats.lua",
  sort_order = 1500,
  menu_entry = {key = "rtt_monitor", i18n_title = "host_config.rtt_monitor", section = "system_stats"},

  is_shown = function()
    local user_scripts = require("user_scripts")

    return(user_scripts.isSystemScriptEnabled("rtt"))
  end
}
