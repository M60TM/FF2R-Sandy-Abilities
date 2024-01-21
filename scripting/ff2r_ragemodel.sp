/*
	"rage_model"
	{
		"slot"		"0"													// Ability slot
		"model"		"models/freak_fortress_2/boss/boss.mdl"				// Model path
		"revert"	"models/freak_fortress_2/boss/boss_lifeloss.mdl"	// Model path
		"duration"	"4.3"												// Ability duration
		
		"plugin_name"	"ff2r_ragemodel"
	}
*/

#include <sourcemod>
#include <sdktools>
#include <cfgmap>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name        = "[FF2R] Rage Model",
	author      = "Sandy",
	description = "No Ways.",
	version     = "1.0.0",
	url         = "",
};

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "rage_model", false) && cfg.IsMyPlugin()) {
		char model[PLATFORM_MAX_PATH];
		if (cfg.GetString("model", model, sizeof(model)) && FileExists(model, true)) {
			SetVariantString(model);
			AcceptEntityInput(client, "SetCustomModelWithClassAnimations");
			
			// Support permanent change when life loss.
			float duration = cfg.GetFloat("duration");
			if (duration) {
				if (cfg.GetString("revert", model, sizeof(model)) && FileExists(model, true)) {
					DataPack pack;
					CreateDataTimer(duration, Timer_ChangeModel, pack, TIMER_FLAG_NO_MAPCHANGE);
					pack.WriteCell(GetClientUserId(client));
					pack.WriteString(model);
					pack.Reset();
				} else {
					CreateTimer(duration, Timer_ResetModel, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
				}
			}
		}
	}
}

public Action Timer_ChangeModel(Handle timer, DataPack pack) {
	int client = GetClientOfUserId(pack.ReadCell());
	if (client && IsPlayerAlive(client)) {
		BossData boss = FF2R_GetBossData(client);
		if (boss) {
			char model[PLATFORM_MAX_PATH];
			if (pack.ReadString(model, sizeof(model))) {
				SetVariantString(model);
				AcceptEntityInput(client, "SetCustomModelWithClassAnimations");
			}
		}
	}

	return Plugin_Continue;
}

public Action Timer_ResetModel(Handle timer, int userid) {
	int client = GetClientOfUserId(userid);
	if (client && IsPlayerAlive(client)) {
		BossData boss = FF2R_GetBossData(client);
		if (boss) {
			char model[PLATFORM_MAX_PATH];
			if (boss.GetString("model", model, sizeof(model)) && FileExists(model, true)) {
				SetVariantString(model);
				AcceptEntityInput(client, "SetCustomModelWithClassAnimations");
			}
		}
	}

	return Plugin_Continue;
}