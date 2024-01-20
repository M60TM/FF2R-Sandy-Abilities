/*
	"rage_bad_effect"	// Remove Bad Effects.
	{
		"jarate"			"true"
		"milk"				"true"
		"stun"				"true"
		"bleed"				"true"
		"marked_for_death"	"true"
		"sapper"			"true"
		
		"taunt"				"true"
		"stop_motion"		"false"
		
		"plugin_name"		"ff2r_dynamic_behavior"
	}
	
	"rage_prevent_taunt"
	{
		"duration"			"15.0"	// Prevent real taunt.
		
		"plugin_name"		"ff2r_dynamic_behavior"
	}
	
	"rage_itsme"
	{
		"initial"		"0.15"	// Initial delay.
		"duration"		"4.0"	// Duration of overlay.
		"path"			""		// Overlay material path.
		"count"			"4"		// Count.
		"delay"			"5.0"	// Delay. Default value is duration + 1s.
		
		"plugin_name"	"ff2r_dynamic_behavior"
	}
	
	"rage_outline"
	{
		"radius"		"600.0"	// Radius. 0 to all player.
		"duration"		"10.0"	// Duration.
		
		"plugin_name"	"ff2r_dynamic_behavior"
	}
	
	"special_stun_breakout"
	{
		"cooldown"		"5.0"	// Cooltime to Re-Perform.
		"radius"		"200.0"	// Radius to deal damage.
		"damage"		"100.0"	// Damage.
		"force"			"300.0"	// Force to push.
		
		"plugin_name"	"ff2r_dynamic_behavior"
	}
	
	"special_kill_log"
	{
		"weaponid"
		{
			"9"	// weaponid to want to change.
			{
				"name"	"fists"	// kill log name.
				"id"	"8"
			}
			"22"	// Correspond to TF_WEAPON_* in tf2.inc.
			{
				"name"	"fists"
				"id"	"8"
			}
		}
		
		"plugin_name"	"ff2r_dynamic_behavior"
	}
	
	"special_rage_on_kill"
	{
		"gain"	"10.0"
		
		"plugin_name"	"ff2r_dynamic_behavior"
	}
	
	"special_heal_on_kill" // Two variations.
	{
		"type"			"0"
		"percentage"	"0.15"
		
		"plugin_name"	"ff2r_dynamic_behavior"
	}
	
	"special_heal_on_kill"
	{
		"type"	"1"
		"gain"	"500.0 + (n * 30.0)"
		
		"plugin_name"	"ff2r_dynamic_behavior"
	}
*/

#include <sourcemod>
#include <dhooks_gameconf_shim>
#include <tf2_stocks>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required

#include <tf2_stun>
#include <tf_damageinfo_tools>
#include <stocksoup/tf/tempents_stocks>

#define MAXTF2PLAYERS MAXPLAYERS + 1

#include "freak_fortress_2/formula_parser.sp"

int PlayersAlive[4];
bool SpecTeam;

ArrayList BossTimers[MAXTF2PLAYERS];

Handle SDKCall_PushAllPlayersAway;

Handle PlayerOutlineTimer[MAXTF2PLAYERS] = { null, ... };
Handle PlayerOverlayTimer[MAXTF2PLAYERS] = { null, ... };

float BlockTauntEndAt[MAXTF2PLAYERS] = { 0.0, ... };

ConVar CvarFriendlyFire;

public Plugin myinfo = {
	name = "[FF2R] Dynamic Behavior",
	author = "Sandy",
	description = "Bunch of misc abilities",
	version = "1.1.0",
	url = ""
};

public void OnPluginStart() {
	GameData data = new GameData("ff2r.sandy");
	if (data == null) {
		SetFailState("Failed to load gamedata(ff2r.sandy.txt).");
	} else if (!ReadDHooksDefinitions("ff2r.sandy")) {
		SetFailState("Failed to read gamedata(ff2r.sandy.txt).");
	}
	
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CTFGameRules::PushAllPlayersAway");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	SDKCall_PushAllPlayersAway = EndPrepSDKCall();

	if (!SDKCall_PushAllPlayersAway) {
		SetFailState("Failed to setup SDKCall for CTFGameRules::PushAllPlayersAway.");
	}
	
	DynamicDetour detour_IsAllowedToTaunt = GetDHooksDetourDefinition(data, "CTFPlayer::IsAllowedToTaunt");
	detour_IsAllowedToTaunt.Enable(Hook_Post, DynDetour_IsAllowedToTaunt);
	
	ClearDHooksDefinitions();
	delete data;
	
	CvarFriendlyFire = FindConVar("mp_friendlyfire");
	
	HookEvent("player_death", OnPlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("object_destroyed", OnObjectDestroyed, EventHookMode_Pre);
	HookEvent("arena_win_panel", OnRoundEnd);
	
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			BossData boss = FF2R_GetBossData(client);
			if (boss) {
				FF2R_OnBossCreated(client, boss, false);
			}
		}
	}
}

public void OnPluginEnd() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			if (PlayerOverlayTimer[client]) {
				TriggerTimer(PlayerOverlayTimer[client]);
			}
			
			if (PlayerOutlineTimer[client]) {
				TriggerTimer(PlayerOutlineTimer[client]);
			}
			
			if (FF2R_GetBossData(client)) {
				FF2R_OnBossRemoved(client);
			}
		}
	}
}

public void OnClientDisconnect(int client) {
	delete PlayerOverlayTimer[client];
	delete PlayerOutlineTimer[client];
}

////
//  Event.
////

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
			
			bool found;
			ConfigData SectionID = ability.GetSection("weaponid");
			if (!SectionID) {
				return Plugin_Continue;
			} else {
				StringMapSnapshot snap = SectionID.Snapshot();
				
				for (int i; i < snap.Length; i++) {
					int length = snap.KeyBufferSize(i) + 1;
					char[] buffer = new char[length];
					snap.GetKey(i, buffer, length);
					
					if (weaponID == StringToInt(buffer)) {
						SectionID = SectionID.GetSection(buffer);
						found = true;
						break;
					}
				}
				
				delete snap;
			}
			
			if (found) {
				char buffer[64];
				SectionID.GetString("name", buffer, sizeof(buffer));
				event.SetString("weapon_logclassname", buffer);
				event.SetString("weapon", buffer);
				event.SetInt("weaponid", SectionID.GetInt("id"));
				
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
		if (PlayerOverlayTimer[victim])
			TriggerTimer(PlayerOverlayTimer[victim]);
		
		// Outline will be disappeared on death.
		delete PlayerOutlineTimer[victim];
		
		if (attacker < 1 || attacker > MaxClients) {
			return;
		}
		
		BossData boss = FF2R_GetBossData(attacker);
		if (boss) {
			AbilityData ability = boss.GetAbility("special_kill_overlay");
			if (ability.IsMyPlugin()) {
				if (!ability.GetBool("dead_ringer") && (event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)) {
					return;
				}
				
				char file[128];
				ability.GetString("path", file, sizeof(file));
				
				SetVariantString(file);
				AcceptEntityInput(victim, "SetScriptOverlayMaterial", victim, victim);
				
				delete PlayerOverlayTimer[victim];
				PlayerOverlayTimer[victim] = CreateTimer(ability.GetFloat("duration", 3.25), Timer_RemovePlayerOverlay, GetClientUserId(victim), TIMER_FLAG_NO_MAPCHANGE);
			}
			
			ability = boss.GetAbility("special_rage_on_kill");
			if (ability.IsMyPlugin()) {
				float gain = GetFormula(cfg, "gain", GetTotalPlayersAlive(CvarFriendlyFire.BoolValue ? -1 : GetClientTeam(client)), 0.0);
				boss.SetCharge(0, Min(boss.GetCharge(0) + gain, boss.RageMax));
			}
			
			ability = boss.GetAbility("special_heal_on_kill");
			if (ability.IsMyPlugin()) {
				Special_HealOnKill(attacker, boss, ability);
			}
		}
	}
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
			
			bool found;
			ConfigData SectionID = ability.GetSection("weaponid");
			if (!SectionID) {
				return Plugin_Continue;
			} else {
				StringMapSnapshot snap = SectionID.Snapshot();
				
				for (int i; i < snap.Length; i++) {
					int length = snap.KeyBufferSize(i) + 1;
					char[] buffer = new char[length];
					snap.GetKey(i, buffer, length);
					
					if (weaponID == StringToInt(buffer)) {
						SectionID = SectionID.GetSection(buffer);
						found = true;
						break;
					}
				}
				
				delete snap;
			}
			
			if (found) {
				char buffer[64];
				SectionID.GetString("name", buffer, sizeof(buffer));
				event.SetString("weapon", buffer);
				event.SetInt("weaponid", SectionID.GetInt("id"));
				
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
	for (int client = 1; client <= MaxClients; client++) {
		if (PlayerOverlayTimer[client])
			TriggerTimer(PlayerOverlayTimer[client]);
		
		if (PlayerOutlineTimer[client])
			TriggerTimer(PlayerOutlineTimer[client]);
	}
}

////
//  FF2R Forwards.
////

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!BossTimers[client]) {
		BossTimers[client] = new ArrayList();
	}
	
	BlockTauntEndAt[client] = 0.0;
	
	if (setup) {
		AbilityData ability = cfg.GetAbility("special_intro_overlay");
		if (ability.IsMyPlugin()) {
			DataPack pack;
			BossTimers[client].Push(CreateDataTimer(ability.GetFloat("delay"), Timer_SpecialIntroOverlay, pack, TIMER_FLAG_NO_MAPCHANGE));
			pack.WriteCell(GetClientUserId(client));
			pack.WriteString("special_intro_overlay");
		}
	}
}

public void FF2R_OnBossRemoved(int client) {
	BlockTauntEndAt[client] = 0.0;
	
	int length = BossTimers[client].Length;
	for (int i; i < length; i++) {
		Handle timer = BossTimers[client].Get(i);
		delete timer;
	}
	
	delete BossTimers[client];
}

public void FF2R_OnAliveChanged(const int alive[4], const int total[4]) {
	for (int i; i < 4; i++) {
		PlayersAlive[i] = alive[i];
	}
	
	SpecTeam = (total[TFTeam_Unassigned] || total[TFTeam_Spectator]);
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "rage_bad_effect") && cfg.IsMyPlugin()) {
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
	} else if (!StrContains(ability, "rage_prevent_taunt", false) && cfg.IsMyPlugin()) {
		BlockTauntEndAt[client] = GetGameTime() + cfg.GetFloat("duration");
	} else if (!StrContains(ability, "rage_itsme", false)) {
		DataPack pack;
		BossTimers[client].Push(CreateDataTimer(cfg.GetFloat("initial", 0.15), Timer_RageItsMe, pack));
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(ability);
		pack.WriteCell(0);
	} else if (!StrContains(ability, "rage_outline", false)) {
		int bossTeam = GetClientTeam(client);
		float duration = cfg.GetFloat("duration");
		float radius = cfg.GetFloat("radius");
		radius = radius * radius;
		
		if (radius) {
			float pos[3], targetPos[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
			
			for (int target = 1; target <= MaxClients; target++) {
				if (target != client && IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target) != bossTeam) {
					GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPos);
					if (GetVectorDistance(pos, targetPos, true) > radius) {
						continue;
					}
					
					SetEntProp(target, Prop_Send, "m_bGlowEnabled", true);
					delete PlayerOutlineTimer[target];
					PlayerOutlineTimer[target] = CreateTimer(duration, Timer_RemoveOutline, GetClientUserId(target));
				}
			}
		} else {
			for (int target = 1; target <= MaxClients; target++) {
				if (target != client && IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target) != bossTeam) {
					SetEntProp(target, Prop_Send, "m_bGlowEnabled", true);
					delete PlayerOutlineTimer[target];
					PlayerOutlineTimer[target] = CreateTimer(duration, Timer_RemoveOutline, GetClientUserId(target));
				}
			}
		}
	}
}

////
//  Functions.
////

public Action Timer_SpecialIntroOverlay(Handle timer, DataPack pack) {
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());

	if (!client)
		return Plugin_Handled;
	
	BossTimers[client].Erase(BossTimers[client].FindValue(timer));
	
	char buffer[64];
	pack.ReadString(buffer, sizeof(buffer));
	
	BossData boss = FF2R_GetBossData(client);
	AbilityData ability = boss.GetAbility(buffer);
	if (ability.IsMyPlugin()) {
		int bossTeam = GetClientTeam(client);
		char file[128];
		
		float duration = ability.GetFloat("duration", 3.25);
		
		ability.GetString("path", file, sizeof(file));
		for (int target = 1; target <= MaxClients; target++) {
			if (IsClientInGame(target) && IsPlayerAlive(target) && (ability.GetBool("self") || GetClientTeam(target) != bossTeam)) {
				SetVariantString(file);
				AcceptEntityInput(target, "SetScriptOverlayMaterial", target, target);
				
				delete PlayerOverlayTimer[target];
				PlayerOverlayTimer[target] = CreateTimer(duration, Timer_RemovePlayerOverlay, GetClientUserId(target), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}

	return Plugin_Continue;
}

void Special_HealOnKill(int client, BossData boss, ConfigData cfg) {
	switch (cfg.GetInt("type")) {
		case 1: {
			int gain = RoundFloat(GetFormula(cfg, "gain", GetTotalPlayersAlive(CvarFriendlyFire.BoolValue ? -1 : GetClientTeam(client)), 0.0));
			
			SetEntityHealth(client, Min(GetClientHealth(client) + gain, boss.MaxHealth));
		}
		default: {
			float percentage = cfg.GetFloat("percentage");
			int health = GetClientHealth(client);
			
			health += RoundFloat(boss.MaxHealth * percentage);
			SetEntityHealth(client, Min(health, boss.MaxHealth));
		}
	}
}

public Action Timer_RageItsMe(Handle timer, DataPack pack) {
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	
	if (!client) {
		return Plugin_Handled;
	}
	
	BossTimers[client].Erase(BossTimers[client].FindValue(timer));
	
	char buffer[64];
	pack.ReadString(buffer, sizeof(buffer));
	
	BossData boss = FF2R_GetBossData(client);
	AbilityData ability = boss.GetAbility(buffer);
	if (ability.IsMyPlugin())
		Rage_ItsMe(client, ability, buffer, pack.ReadCell());

	return Plugin_Handled;
}

public void Rage_ItsMe(int client, ConfigData cfg, const char[] ability, int count) {
	if (!IsPlayerAlive(client)) {
		return;
	}
	
	int bossTeam = GetClientTeam(client);
	float duration = cfg.GetFloat("duration", 4.0);
	
	char file[128];
	cfg.GetString("path", file, sizeof(file));
	for (int target = 1; target <= MaxClients; target++) {
		if (IsClientInGame(target) && IsPlayerAlive(target) && GetClientTeam(target) != bossTeam) {
			SetVariantString(file);
			AcceptEntityInput(target, "SetScriptOverlayMaterial", target, target);
				
			delete PlayerOverlayTimer[target];
			PlayerOverlayTimer[target] = CreateTimer(duration, Timer_RemovePlayerOverlay, GetClientUserId(target), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	if (cfg.GetInt("count", 4) > count) {
		DataPack pack;
		BossTimers[client].Push(CreateDataTimer(cfg.GetFloat("delay", duration + 1.0), Timer_RageItsMe, pack));
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(ability);
		pack.WriteCell(count + 1);
	}
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

public Action Timer_RemoveOutline(Handle timer, int userid) {
	int client = GetClientOfUserId(userid);
	
	if (client) {
		PlayerOutlineTimer[client] = null;
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", false);
	}
	return Plugin_Continue;
}

public void TF2_OnRemoveStunned(int client, float duration, int slowdown, int stunflags, int stunner) {
	if (stunflags & TF_STUNFLAG_BONKSTUCK || stunflags & TF_STUNFLAGS_SMALLBONK) {
		BossData boss = FF2R_GetBossData(client);
		if (boss) {
			AbilityData ability = boss.GetAbility("special_stun_breakout");
			
			float gameTime = GetGameTime();
			if (ability.IsMyPlugin() && gameTime > ability.GetFloat("delay")) {
				PerformBreakOut(client, ability);
				ability.SetFloat("delay", gameTime + ability.GetFloat("cooldown"));
			}
		}
	}
}

void PerformBreakOut(int client, ConfigData cfg) {
	float pos[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos);
	
	float radius = cfg.GetFloat("radius", 200.0);
	float damage = cfg.GetFloat("damage", 100.0);
	
	char particle[64];
	if (cfg.GetString("particle", particle, sizeof(particle), "hammer_impact_button_dust2")) {
		TE_SetupTFParticleEffect(particle, pos);
		TE_SendToAll();
	}
	
	CTakeDamageInfo damageInfo = new CTakeDamageInfo(client, client, damage, DMG_SLASH | DMG_USEDISTANCEMOD | DMG_HALF_FALLOFF, -1, _, pos);
	
	CTFRadiusDamageInfo radiusInfo = new CTFRadiusDamageInfo(damageInfo, pos, radius, client);
	
	radiusInfo.Apply();
	
	delete radiusInfo;
	delete damageInfo;
	
	damage = cfg.GetFloat("force", 300.0);
	SDKCall(SDKCall_PushAllPlayersAway, pos, radius, force, GetClientTeam(client) == 2 ? 3 : 2, 0);
}

MRESReturn DynDetour_IsAllowedToTaunt(int client, DHookReturn ret) {
	if (BlockTauntEndAt[client] >= GetGameTime()) {
		ret.Value = false;
		return MRES_Override;
	}
	
	return MRES_Ignored;
}

float GetFormula(ConfigData cfg, const char[] key, int players, float defaul = 0.0) {
	static char buffer[1024];
	if (!cfg.GetString(key, buffer, sizeof(buffer)))
		return defaul;
	
	return ParseFormula(buffer, players);
}

int GetTotalPlayersAlive(int team = -1) {
	int amount;
	for (int i = SpecTeam ? 0 : 2; i < sizeof(PlayersAlive); i++) {
		if(i != team)
			amount += PlayersAlive[i];
	}
	
	return amount;
}

stock any Min(any a, any b) {
	return a > b ? b : a;
}