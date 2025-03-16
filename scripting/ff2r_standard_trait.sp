/*
	"special_kill_log"
	{
		"weaponid"
		{
			"8"
			{
				"name"	"fists"
			}
		}
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"special_kill_overlay"
	{
		"duration"	"3.25"
		"path"		""
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"special_rage_on_kill"
	{
		"slot"		"0"
		"amount"	"10.0"
		"subtract"	"false"
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"special_heal_on_kill"
	{
		"milk"			"false"
		"type"			"0"
		"multiplier"	"2.0"
		"gain"			"300.0 + n"
		"percentage"	"0.05"
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"passive_blockdropitem"
	{
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"special_boss_attribute"
	{
		"attributes"
		{
			"dmg from ranged reduced"		"0.8 ; -1.0"	// 205
			"damage force reduction"		"0.4 ; -1.0"	// 252
			"cannot pick up intelligence"	"1.0 ; -1.0"	// 400
		}
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"rage_special_theme"
	{
		"slot"		"0"
		"required"	""
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"sound_special_theme"
	{
		"neon_inferno/ff2/painiscupcake/rage.mp3"
		{
			"key"	""
			"time"	"16"
		}
	}
	
	"rage_boss_attribute"
	{
		"slot"		"0"
		"attributes"
		{
			"melee attack rate bonus"			"0.6 ; 7.0"
		}
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"rage_boss_attribute"
	{
		"slot"		"0"
		"attributes"
		{
			"melee attack rate bonus"
			{
				"value"		"0.7"
				"duration"	"7.0 + (n / 10)"
			}
		}
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"rage_bad_effect"
	{
		"slot"				"0"
		"jarate"			"true"
		"milk"				"true"
		"stun"				"true"
		"bleed"				"true"
		"marked_for_death"	"true"
		"sapper"			"true"
		"taunt"				"true"
		"stop_motion"		"false"
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"rage_movespeed"
	{
		"slot"			"0"
		"duration"		"7.0 + (n / 10)"
		"distance"		"300.0"
		"self_speed"	"520.0"
		"ally_speed"	"0.0"
		"enemy_speed"	"0.0"
		
		"plugin_name"	"ff2r_standard_trait"
	}
*/
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <cfgmap>
#include <ff2r>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

#define DEFINDEX_UNDEFINED 65535

#include <stocksoup/tf/tempents_stocks>
#include "freak_fortress_2/formula_parser.sp"

Handle SDKGetMaxHealth;
Handle SDKRemoveAllCustomAttribute;

int PlayersAlive[4];
bool SpecTeam;

bool NoActive[MAXPLAYERS + 1] = { false, ... };
bool BlockDropRune[MAXPLAYERS + 1];

ArrayList BossTimers[MAXPLAYERS + 1];

float MoveSpeed[MAXPLAYERS + 1];
float MoveSpeedDuration[MAXPLAYERS + 1];

Handle PlayerOverlayTimer[MAXPLAYERS + 1] = { null, ... };

ConVar CvarFriendlyFire;

public void OnPluginStart() {
	GameData gamedata = new GameData("sdkhooks.games");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	SDKGetMaxHealth = EndPrepSDKCall();
	if (!SDKGetMaxHealth)
		LogError("[Gamedata] Could not find GetMaxHealth");
	
	delete gamedata;
	
	gamedata = new GameData("ff2r.sandy");
	if (!gamedata)
		SetFailState("Failed to load gamedata (ff2r.sandy).");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::RemoveAllCustomAttributes");
	SDKRemoveAllCustomAttribute = EndPrepSDKCall();
	if (!SDKRemoveAllCustomAttribute)
		SetFailState("[Gamedata] Could not find CTFPlayer::RemoveAllCustomAttributes");
	
	delete gamedata;
	
	AddCommandListener(Command_DropItem, "dropitem");
	
	CvarFriendlyFire = FindConVar("mp_friendlyfire");
	
	HookEvent("player_death", OnPlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("object_destroyed", OnObjectDestroyed, EventHookMode_Pre);
	
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			BossData cfg = FF2R_GetBossData(client);
			if (cfg) {
				FF2R_OnBossCreated(client, cfg, false);
			}
		}
	}
}

public void OnPluginEnd() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			if (PlayerOverlayTimer[client])
				TriggerTimer(PlayerOverlayTimer[client]);
			
			if (FF2R_GetBossData(client))
				FF2R_OnBossRemoved(client);
		}
	}
}

public void OnClientDisconnect(int client) {
	delete PlayerOverlayTimer[client];
}

public Action OnPlayerDeathPre(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker) {
		return Plugin_Continue;
	}
	
	BossData boss = FF2R_GetBossData(attacker);
	if (boss) {
		AbilityData ability = boss.GetAbility("special_kill_log");
		if (ability.IsMyPlugin()) {
			int weaponID = event.GetInt("weaponid");
			
			char buffer[64];
			Format(buffer, sizeof(buffer), "weaponid.%d", weaponID);
			ConfigData SectionID = ability.GetSection(buffer);
			if (SectionID) {
				SectionID.GetString("name", buffer, sizeof(buffer));
				event.SetString("weapon_logclassname", buffer);
				event.SetString("weapon", buffer);
				
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public Action OnObjectDestroyed(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker) {
		return Plugin_Continue;
	}
	
	BossData boss = FF2R_GetBossData(attacker);
	if (boss) {
		AbilityData ability = boss.GetAbility("special_kill_log");
		if (ability.IsMyPlugin()) {
			int weaponID = event.GetInt("weaponid");
			
			char buffer[64];
			Format(buffer, sizeof(buffer), "weaponid.%d", weaponID);
			ConfigData SectionID = ability.GetSection(buffer);
			if (SectionID) {
				SectionID.GetString("name", buffer, sizeof(buffer));
				event.SetString("weapon_logclassname", buffer);
				event.SetString("weapon", buffer);
				
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (victim) {
		if (attacker < 1 || attacker > MaxClients || attacker == victim) {
			return;
		}
		
		BossData boss = FF2R_GetBossData(attacker);
		if (boss) {
			AbilityData ability = boss.GetAbility("special_kill_overlay");
			if (ability.IsMyPlugin()) {
				if (!ability.GetBool("dead_ringer") || !(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)) {
					char file[128];
					ability.GetString("path", file, sizeof(file));
					
					SetVariantString(file);
					AcceptEntityInput(victim, "SetScriptOverlayMaterial", victim, victim);
					
					delete PlayerOverlayTimer[victim];
					PlayerOverlayTimer[victim] = CreateTimer(ability.GetFloat("duration", 3.25), Timer_RemovePlayerOverlay, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);
				}
			}
			
			ability = boss.GetAbility("special_rage_on_kill");
			if (ability.IsMyPlugin()) {
				if (boss.RageDamage > 0.0) {
					float amount = GetFormula(ability, "amount", TotalPlayersAliveEnemy(CvarFriendlyFire.BoolValue ? -1 : GetClientTeam(attacker)), 0.0);
					
					char slot[8];
					ability.GetString("slot", slot, sizeof(slot), "0");
					
					float rage = GetBossCharge(boss, slot);
					float maxrage = boss.RageMax;
					if (rage < maxrage) {
						rage += amount;
						if (rage > maxrage) {
							FF2R_EmitBossSoundToAll("sound_full_rage", attacker, _, attacker, SNDCHAN_AUTO, SNDLEVEL_AIRCRAFT, _, 2.0);
							rage = maxrage;
						}
						else if (rage < 0.0) {
							rage = 0.0;
						}
						
						SetBossCharge(boss, slot, rage);
					}
				}
			}
			
			ability = boss.GetAbility("special_heal_on_kill");
			if (ability.IsMyPlugin() && ApplyHealOnKill(attacker, victim, ability)) {
				FF2R_UpdateBossAttributes(attacker);
			}
			
			if (event.GetInt("customkill") == TF_CUSTOM_BACKSTAB) {
				ability = boss.GetAbility("special_disguise_on_backstab");
				if (ability.IsMyPlugin()) {
					TFTeam team = TF2_GetClientTeam(victim);
					TFClassType classType = TF2_GetPlayerClass(victim);
					TF2_DisguisePlayer(attacker, team, classType, victim);
				}
			}
		}
	}
}

public Action Command_DropItem(int client, const char[] command, int argc) {
	if (IsClientInGame(client)) {
		if (BlockDropRune[client]) {
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (StrEqual(classname, "item_powerup_rune"))
		AcceptEntityInput(entity, "Kill");
}

public void OnPreThink(int client) {
	if (GetGameTime() > MoveSpeedDuration[client]) {
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.001);
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);
		return;
	}
	
	SetEntPropFloat(client, Prop_Data, "m_flMaxspeed", MoveSpeed[client]);
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!BossTimers[client]) {
		BossTimers[client] = new ArrayList();
	}
	
	if (!BlockDropRune[client]) {
		AbilityData ability = cfg.GetAbility("special_blockdropitem");
		if (ability.IsMyPlugin()) {
			BlockDropRune[client] = true;
		}
		else {
			ability = cfg.GetAbility("passive_blockdropitem");
			if (ability.IsMyPlugin())
				BlockDropRune[client] = true;
		}
	}
}

public void FF2R_OnBossEquipped(int client, bool weapons) {
	AbilityData ability = FF2R_GetBossData(client).GetAbility("special_boss_attribute");
	if (ability.IsMyPlugin()) {
		ApplyBossAttributes(client, ability);
	}
}

public void FF2R_OnBossRemoved(int client) {
	int length = BossTimers[client].Length;
	for (int i; i < length; i++) {
		Handle timer = BossTimers[client].Get(i);
		delete timer;
	}
	delete BossTimers[client];
	
	BlockDropRune[client] = false;
	
	// If you death, game should be call this function. But you changed boss, custom attribute is still remaining.
	// So here is fix for that.
	if (IsPlayerAlive(client)) {
		SDKCall(SDKRemoveAllCustomAttribute, client);
	}
}

public Action FF2R_OnAbilityPre(int client, const char[] ability, AbilityData cfg, bool &result) {
	return NoActive[client] ? Plugin_Stop : Plugin_Continue;
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "rage_special_theme")) {
		char required[8];
		cfg.GetString("required", required, sizeof(required));
		FF2R_EmitBossSoundToAll("sound_special_theme", client, required);
	}
	else if (!StrContains(ability, "rage_boss_attribute", false)) {
		ApplyBossAttributes(client, cfg);
	}
	else if (!StrContains(ability, "rage_bad_effect", false)) {
		if (cfg.GetBool("jarate", true)) {
			TF2_RemoveCondition(client, TFCond_Jarated);
		}
		
		if (cfg.GetBool("milk", true)) {
			TF2_RemoveCondition(client, TFCond_Milked);
		}
		
		if (cfg.GetBool("stun", true)) {
			TF2_RemoveCondition(client, TFCond_Dazed);
		}
		
		if (cfg.GetBool("bleed", true)) {
			TF2_RemoveCondition(client, TFCond_Bleeding);
		}
		
		if (cfg.GetBool("marked_for_death", true)) {
			TF2_RemoveCondition(client, TFCond_MarkedForDeath);
		}
		
		if (cfg.GetBool("sapper", true)) {
			TF2_RemoveCondition(client, TFCond_Dazed);
			TF2_RemoveCondition(client, TFCond_Sapped);
		}
		
		if (cfg.GetBool("taunt", true)) {
			TF2_RemoveCondition(client, TFCond_Taunting);
			if (cfg.GetBool("stop_motion", false)) {
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, {0.0, 0.0, 200.0});
			}
		}
	}
	else if (!StrContains(ability, "rage_movespeed", false)) {
		DataPack pack;
		BossTimers[client].Push(CreateDataTimer(GetFormula(cfg, "delay", TotalPlayersAliveEnemy(CvarFriendlyFire.BoolValue ? -1 : GetClientTeam(client))), Timer_RageMoveSpeed, pack, TIMER_FLAG_NO_MAPCHANGE));
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(ability);
	}
}

public void FF2R_OnAliveChanged(const int alive[4], const int total[4]) {
	for (int i; i < 4; i++) {
		PlayersAlive[i] = alive[i];
	}
	
	SpecTeam = (total[TFTeam_Unassigned] || total[TFTeam_Spectator]);
}

public void FF2R_OnBossModifier(int client, ConfigData cfg) {
	BossData boss = FF2R_GetBossData(client);
	
	if (cfg.GetBool("noactive")) {
		NoActive[client] = true;
		
		if (boss.GetAbility("special_rage_on_kill").IsMyPlugin())
			boss.Remove("special_rage_on_kill");
	}
}

bool ApplyHealOnKill(int client, int victim, ConfigData cfg) {
	if (cfg.GetBool("milk") && !TF2_IsPlayerInCondition(victim, TFCond_Milked)) {
		return false;
	}
	
	int amount = 0;
	switch (cfg.GetInt("type")) {
		case 1: {
			amount = RoundFloat(GetFormula(cfg, "gain", TotalPlayersAliveEnemy(CvarFriendlyFire.BoolValue ? -1 : GetClientTeam(client)), 0.0));
		}
		case 2: {
			amount = RoundFloat(GetClientMaxHealth(client) * cfg.GetFloat("percentage"));
		}
		default: {
			amount = RoundFloat(GetClientMaxHealth(victim) * cfg.GetFloat("multiplier", 1.0));
		}
	}
	
	if (amount > 0) {
		int health = Min(GetClientHealth(client) + amount, GetClientMaxHealth(client));
		SetEntityHealth(client, health);
		
		Event event = CreateEvent("player_healonhit", true);
	
		event.SetInt("entindex", client);
		event.SetInt("amount", amount);
		
		event.Fire();
	}
	
	return true;
}

void ApplyBossAttributes(int client, ConfigData cfg) {
	ConfigData cfgAttribute = cfg.GetSection("attributes");
	StringMapSnapshot snap = cfgAttribute.Snapshot();
	
	PackVal attributeValue;
	
	int team = GetClientTeam(client);
	int alive = TotalPlayersAliveEnemy(CvarFriendlyFire.BoolValue ? -1 : team);
	
	int entries = snap.Length;
	char buffer[2][64];
	for (int i; i < entries; i++) {
		int length = snap.KeyBufferSize(i) + 1;
		char[] key = new char[length];
		snap.GetKey(i, key, length);
		
		if (cfgAttribute.GetArray(key, attributeValue, sizeof(attributeValue))) {
			switch (attributeValue.tag) {
				case KeyValType_Value: {
					ExplodeString(attributeValue.data, ";", buffer, sizeof(buffer), sizeof(buffer[]));
					float value = ParseFormula(buffer[0], alive);
					float duration = ParseFormula(buffer[1], alive);
					TF2Attrib_AddCustomPlayerAttribute(client, key, value, duration);
				}
				case KeyValType_Section: {
					float value = GetFormula(view_as<ConfigData>(attributeValue.cfg), "value", alive);
					float duration = GetFormula(view_as<ConfigData>(attributeValue.cfg), "duration", alive);
					TF2Attrib_AddCustomPlayerAttribute(client, key, value, duration);
				}
			}
		}
	}
	
	delete snap;
}

public Action Timer_RageMoveSpeed(Handle timer, DataPack pack) {
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());

	if (!client)
		return Plugin_Handled;
	
	BossTimers[client].Erase(BossTimers[client].FindValue(timer));
	
	char buffer[64];
	pack.ReadString(buffer, sizeof(buffer));
	
	BossData boss = FF2R_GetBossData(client);
	AbilityData cfg = boss.GetAbility(buffer);
	if (cfg.IsMyPlugin()) {
		int team = GetClientTeam(client);
		float duration = GetFormula(cfg, "duration", TotalPlayersAliveEnemy(CvarFriendlyFire.BoolValue ? -1 : team));
		float gameTime = GetGameTime();
		
		float mySpeed = cfg.GetFloat("self_speed", 520.0);
		if (mySpeed > 0.0) {
			MoveSpeed[client] = mySpeed;
			MoveSpeedDuration[client] = gameTime + duration;
			SDKHook(client, SDKHook_PreThink, OnPreThink);
		}
		
		float pos1[3], pos2[3];
		GetClientEyePosition(client, pos1);
		
		float distance = cfg.GetFloat("distance", 300.0);
		distance = distance * distance;
		
		float allySpeed = cfg.GetFloat("ally_speed", 0.0);
		float enemySpeed = cfg.GetFloat("enemy_speed", 0.0);
		if (allySpeed > 0.0 || enemySpeed > 0.0) {
			for (int target = 1; target <= MaxClients; target++) {
				if (target == client || !IsClientInGame(target) || !IsPlayerAlive(target)) {
					continue;
				}
				
				GetClientEyePosition(target, pos2);
				if (GetVectorDistance(pos1, pos2, true) > distance) {
					continue;
				}
				
				if (team == GetClientTeam(target)) {
					if (allySpeed <= 0.0) {
						continue;
					}
					
					MoveSpeed[target] = allySpeed;
					MoveSpeedDuration[client] = gameTime + duration;
					SDKHook(target, SDKHook_PreThink, OnPreThink);
				}
				else {
					if (enemySpeed <= 0.0) {
						continue;
					}
					
					MoveSpeed[target] = enemySpeed;
					MoveSpeedDuration[client] = gameTime + duration;
					SDKHook(target, SDKHook_PreThink, OnPreThink);
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_RemovePlayerOverlay(Handle timer, int userid) {
	int client = GetClientOfUserId(userid);
	
	if (client) {
		PlayerOverlayTimer[client] = null;
		SetVariantString("");
		AcceptEntityInput(client, "SetScriptOverlayMaterial", client, client);
	}
	return Plugin_Continue;
}

float GetFormula(ConfigData cfg, const char[] key, int players, float defaul = 0.0) {
	static char buffer[1024];
	if (!cfg.GetString(key, buffer, sizeof(buffer)))
		return defaul;
	
	return ParseFormula(buffer, players);
}

float GetBossCharge(ConfigData cfg, const char[] slot, float defaul = 0.0) {
	int length = strlen(slot)+7;
	char[] buffer = new char[length];
	Format(buffer, length, "charge%s", slot);
	return cfg.GetFloat(buffer, defaul);
}

void SetBossCharge(ConfigData cfg, const char[] slot, float amount) {
	int length = strlen(slot)+7;
	char[] buffer = new char[length];
	Format(buffer, length, "charge%s", slot);
	cfg.SetFloat(buffer, amount);
}

int TotalPlayersAliveEnemy(int team = -1) {
	int amount;
	for (int i = SpecTeam ? 0 : 2; i < sizeof(PlayersAlive); i++) {
		if (i != team)
			amount += PlayersAlive[i];
	}
	
	return amount;
}

int GetClientMaxHealth(int client) {
	return SDKGetMaxHealth ? SDKCall(SDKGetMaxHealth, client) : GetEntProp(client, Prop_Data, "m_iMaxHealth");
}

stock any Min(any a, any b) {
	return a > b ? b : a;
}