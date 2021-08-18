# ConVar Enforcer

For those that have ever run a server in CSGO before, they probably ended up having to use a plugin that forces their server's cvars because for some reason they just changed on their own! This plugin is meant to be an end-all fix for that problem. I know that I'm definitely not the first person to make this kind of plugin, however I can't find it on alliedmods. Do I have bad search skills or is it actually the case that no one has released a plugin that does this publicly?

## Installation
Merge the sourcemod folder from the download with your server's sourcemod folder.

## Configuration
Inside sourcemod/configs/cvarenf.cfg, you can list cvars and the values you expect. Here is an example:

## Example
sv_full_alltalk 1
sv_deadtalk 1
sv_alltalk 1
sv_allow_votes 0
mp_roundtime 60
mp_timelimit 60
mp_limitteams 0
mp_autoteambalance 0
mp_freezetime 0
bot_quota 1
bot_quota_mode match
sv_airaccelerate 1000
sv_hibernate_when_empty 0
mp_warmuptime 0
mp_do_warmup_period 0
mp_autokick 0
sv_friction 4
sv_accelerate 5
sv_staminajumpcost 0
sv_staminalandcost 0
sv_infinite_ammo 1
host_players_show 2
mp_maxmoney 0
mp_maxrounds 1
sv_max_allowed_net_graph 3
sv_enablebunnyhopping 1
bot_controllable 0
mp_ignore_round_win_conditions 1
sv_allow_thirdperson 1

## Note
It's okay to have quotes, the plugin will ignore them. Right now I'm not entirely sure that the way I'm reading the cvarenf.cfg file is the proper way to do it, but from my experience with the file system it should be okay I think 

You can reload the config file ingame through the admin menu's "Server Commands" category. Requires the config admin flag ("i"). The plugin itself is also reloadable.
