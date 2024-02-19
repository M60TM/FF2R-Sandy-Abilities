/*
	"special_tfcondition"
	{
		"condition"
		{
			"TF_COND_CRITBOOSTED_FIRST_BLOOD"	"8.0"
			"TF_COND_SPEED_BOOST"				"8.0"
		}
		
		"additive"		"true"
		
		"plugin_name"	"ff2r_tfcondition"
	}
	
	"rage_tfcondition"	// Can suffixed.
	{
		"slot"		"0"
		"additive"	"true"
		
		"condition"	// Named Condition Support!
		{
			"TF_COND_CRITBOOSTED_FIRST_BLOOD"	"8.0"
			"TF_COND_SPEED_BOOST"				"8.0"
		}
		
		"radius"			"700.0"		// Radius.
		"ally_condition"	"32 ; 10"	// Conditions to add ally. Still support condition index.
		"victim_condition"	"30 ; 10"	// Conditions to add victim.

		"plugin_name"	"ff2r_tfcondition"
	}
*/

#include <sourcemod>
#include <tf2_stocks>
#include <cfgmap>
#include <ff2r>
#include <tf2utils>

#pragma semicolon 1
#pragma newdecls required

ArrayList BossTimers[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[FF2R] TFConditions",
	author = "Sandy and 93SHADoW",
	description = "Coming with cfgmap :D",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	HookEvent("teamplay_round_win", OnRoundEnd);
	
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			BossData cfg = FF2R_GetBossData(client);
			if (cfg) {
				FF2R_OnBossCreated(client, cfg, false);
			}
		}
	}
}

// Hotfix for Team Switch wasn't applied if target has HalloweenKart Condition.
public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
	// Otherwise, not enabled.
	if (FF2R_GetGamemodeType() != 2) {
		return;
	}
	
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			TF2_RemoveCondition(client, TFCond_HalloweenKart);
		}
	}
}

// Hotfix for RuneHaste's speed buff doesn't applied on boss until it damaged.
public void TF2_OnConditionAdded(int client, TFCond condition) {
	if (condition == TFCond_RuneHaste) {
		if (FF2R_GetBossData(client)) {
			FF2R_UpdateBossAttributes(client);
		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition) {
	if (condition == TFCond_RuneHaste) {
		if (FF2R_GetBossData(client)) {
			FF2R_UpdateBossAttributes(client);
		}
	}
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!BossTimers[client]) {
		BossTimers[client] = new ArrayList();
	}
	
	if (!setup || FF2R_GetGamemodeType() != 2) {
		AbilityData ability = cfg.GetAbility("special_tfcondition");
		if (ability.IsMyPlugin()) {
			ApplyTFConditionData(client, cfg, "condition", ability.GetBool("additive", true));
		}
	}
}

public void FF2R_OnBossRemoved(int client) {
	int length = BossTimers[client].Length;
	for (int i; i < length; i++) {
		Handle timer = BossTimers[client].Get(i);
		delete timer;
	}
	
	delete BossTimers[client];
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "rage_tfcondition", false)) {
		DataPack pack;
		BossTimers[client].Push(CreateDataTimer(cfg.GetFloat("delay", 0.1), Timer_RageTFCondition, pack, TIMER_FLAG_NO_MAPCHANGE));
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(ability);
	}
}

public Action Timer_RageTFCondition(Handle timer, DataPack pack) {
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());

	if (!client) {
		return Plugin_Handled;		
	}

	BossTimers[client].Erase(BossTimers[client].FindValue(timer));
	
	char buffer[64];
	pack.ReadString(buffer, sizeof(buffer));
	
	BossData boss = FF2R_GetBossData(client);
	AbilityData cfg = boss.GetAbility(buffer);
	if (cfg.IsMyPlugin()) {
		bool additive = cfg.GetBool("additive", true);
	
		ApplyTFConditionData(client, cfg, "condition", additive);
		
		bool ally = cfg.GetKeyValType("ally_condition") != KeyValType_Null;
		bool victim = cfg.GetKeyValType("victim_condition") != KeyValType_Null;
		if (!ally && !victim) {
			return Plugin_Continue;
		}
		
		float radius = cfg.GetFloat("radius");
		radius = radius * radius;
		
		int bossTeam = GetClientTeam(client);
		
		if (radius > 0.0) {
			float pos[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
			for (int target = 1; target <= MaxClients; target++) {	
				if (target != client && IsClientInGame(target) && IsPlayerAlive(target)) {
					float targetPos[3];
					GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPos);
					if (GetVectorDistance(pos, targetPos, true) > radius) {
						continue;
					}
					
					if (victim && GetClientTeam(target) != bossTeam) {
						ApplyTFConditionData(target, cfg, "victim_condition", additive);
					} else if (ally && GetClientTeam(target) == bossTeam) {
						ApplyTFConditionData(target, cfg, "ally_condition", additive);
					}
				}
			}
		} else {
			for (int target = 1; target <= MaxClients; target++) {
				if (target != client && IsClientInGame(target) && IsPlayerAlive(target)) {
					if (victim && GetClientTeam(target) != bossTeam) {
						ApplyTFConditionData(target, cfg, "victim_condition", additive);
					} else if (ally && GetClientTeam(target) == bossTeam) {
						ApplyTFConditionData(target, cfg, "ally_condition", additive);
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

void ApplyTFConditionData(int client, ConfigData cfg, const char[] key, bool additive) {
	switch (cfg.GetKeyValType(key)) {
		case KeyValType_Section: {
			ConfigData condition = cfg.GetSection(key);
			StringMapSnapshot snap = condition.Snapshot();
			
			TFCond cond;
			int entries = snap.Length;
			for (int i; i < entries; i++) {
				int length = snap.KeyBufferSize(i) + 1;
				char[] buffer = new char[length];
				snap.GetKey(i, buffer, length);
				
				if (TranslateTFCond(buffer, cond)) {
					float duration = condition.GetFloat(buffer);
					ApplyTFCondition(client, cond, duration, additive);
				}
			}
			
			delete snap;
		}
		case KeyValType_Value: {
			char condition[PLATFORM_MAX_PATH];
			if (!cfg.GetString(key, condition, sizeof(condition))) {
				return;
			}
			
			char conds[16][16];
			int count = ExplodeString(condition, ";", conds, sizeof(conds), sizeof(conds[]));
			if (count > 0) {
				for (int i = 0; i < count; i += 2) {
					TFCond cond = view_as<TFCond>(StringToInt(conds[i]));
					float duration = StringToFloat(conds[i + 1]);
					ApplyTFCondition(client, cond, duration, additive);
				}
			}
		}
		case KeyValType_Null: {
			return;
		}
	}
}

void ApplyTFCondition(int client, TFCond cond, float duration, bool additive) {
	if (!TF2_IsPlayerInCondition(client, cond)) {
		if (duration < 0.0)
			duration = TFCondDuration_Infinite;
						
		TF2_AddCondition(client, cond, duration);
	} else {
		if (!additive) {
			return;
		}
		
		float currentDuration = TF2Util_GetPlayerConditionDuration(client, cond);
		TF2Util_SetPlayerConditionDuration(client, cond, currentDuration + duration);
	}
}

stock bool TranslateTFCond(const char[] name, TFCond &value) {
	int result;
	if (StringToIntEx(name, result)) {
		value = view_as<TFCond>(result);
		return true;
	}
	
	static StringMap s_Conditions;
	if (!s_Conditions) {
		char buffer[64];
		
		s_Conditions = new StringMap();
		for (TFCond cond; cond <= TF2Util_GetLastCondition(); cond++) {
			if (TF2Util_GetConditionName(cond, buffer, sizeof(buffer))) {
				s_Conditions.SetValue(buffer, cond);
			}
		}
	}
	
	if (s_Conditions.GetValue(name, value)) {
		return true;
	}
	
	// log message if given string does not resolve to a condition
	static StringMap s_LoggedConditions;
	if (!s_LoggedConditions) {
		s_LoggedConditions = new StringMap();
	}
	any ignored;
	if (!s_LoggedConditions.GetValue(name, ignored)) {
		LogError("Could not translate condition name %s to index.", name);
		s_LoggedConditions.SetValue(name, true);
	}
	return false;
}