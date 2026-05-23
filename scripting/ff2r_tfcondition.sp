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
		
		"self"
		{
			"additive"	"true"
			"condition"	// Named Condition Support!
			{
				"TF_COND_CRITBOOSTED_FIRST_BLOOD"	"8.0 + (n * 0.2)"	// Formula support.
				"TF_COND_SPEED_BOOST"				"8.0"
			}
		}
		"ally" // Conditions to add ally. 
		{
			"radius"	"500.0"
			"additive"	"false"
			"condition" "32 ; 10"	// Still support condition index.
		}
		"enemy"
		{
			"radius"	"900.0"
			"additive"	"false"
			"condition" "30 ; 10"
		}
		
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

#include "freak_fortress_2/formula_parser.sp"

enum ConditionApplyType {
	ApplyType_Self = 0,
	ApplyType_Ally,
	ApplyType_Enemy,
};

ArrayList BossTimers[MAXPLAYERS + 1];

ConVar mp_friendlyfire;

int PlayersAlive[4];
bool SpecTeam;

public Plugin myinfo = {
	name = "[FF2R] TFConditions",
	author = "Sandy and 93SHADoW",
	description = "Coming with cfgmap :D",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	HookEvent("teamplay_round_win", OnRoundEnd);
	
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	
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
			ApplyTFConditionCfg(client, ApplyType_Self, ability);
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
		BossTimers[client].Push(CreateDataTimer(GetFormula(cfg, "delay", TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : GetClientTeam(client))), Timer_RageTFCondition, pack, TIMER_FLAG_NO_MAPCHANGE));
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
		ApplyTFConditionCfg(client, ApplyType_Self, cfg.GetSection("self"));
		ApplyTFConditionCfg(client, ApplyType_Ally, cfg.GetSection("ally"));
		ApplyTFConditionCfg(client, ApplyType_Enemy, cfg.GetSection("enemy"));
	}
	
	return Plugin_Continue;
}

/*
void ApplyTFConditionString(int client, const char[] condition, bool additive) {
	char conds[16][16];
	int count = ExplodeString(condition, ";", conds, sizeof(conds), sizeof(conds[]));
	if (count > 0) {
		for (int i = 0; i < count; i += 2) {
			TFCond cond = view_as<TFCond>(StringToInt(conds[i]));
			float duration = ParseFormula(conds[i + 1], TotalPlayersAliveEnemy(CvarFriendlyFire.BoolValue ? -1 : GetClientTeam(client)));
			ApplyTFCondition(client, cond, duration, additive);
		}
	}
}
*/

void ApplyTFConditionCfg(int client, ConditionApplyType type, ConfigData cfg) {
	if (cfg == null)
		return;
	
	switch (type) {
		case ApplyType_Self: {
			ApplyTFConditionsToClient(client, cfg);
		}
		case ApplyType_Ally, ApplyType_Enemy: {
			float radius = cfg.GetFloat("radius");
			bool outside = radius < 0.0;
			radius = radius * radius;
			
			int team = GetClientTeam(client);
			
			int[] clients = new int[MaxClients + 1];
			int amount;
			
			if (radius > 0.0) {
				float pos[3], pos2[3];
				GetClientAbsOrigin(client, pos);
				
				for (int target = 1; target <= MaxClients; target++) {
					if (target == client || !IsClientInGame(target) || !IsPlayerAlive(target))
						continue;
					
					bool inSameTeam = GetClientTeam(target) == team;
					if ((type == ApplyType_Ally && !inSameTeam) || (type == ApplyType_Enemy && inSameTeam))
						continue;
					
					GetClientAbsOrigin(target, pos2);
					float distance = GetVectorDistance(pos, pos2, true);
					if ((!outside && distance > radius) || (outside && distance <= radius))
						continue;
					
					clients[amount++] = target;
				}
			}
			else {
				for (int target = 1; target <= MaxClients; target++) {
					if (target == client || !IsClientInGame(target) || !IsPlayerAlive(target))
						continue;
					
					bool inSameTeam = GetClientTeam(target) == team;
					if ((type == ApplyType_Ally && !inSameTeam) || (type == ApplyType_Enemy && inSameTeam))
						continue;
					
					clients[amount++] = target;
				}
			}
			
			ApplyTFConditions(clients, amount, team, cfg);
		}
	}
}

void ApplyTFConditionsToClient(int client, ConfigData cfg) {
	int clients[1];
	clients[0] = client;
	ApplyTFConditions(clients, 1, GetClientTeam(client), cfg);
}

void ApplyTFConditions(int[] clients, int numClients, int team, ConfigData cfg) {
	PackVal val; cfg.GetVal("condition", val);	
	bool additive = cfg.GetBool("additive", true);
	bool friendly = mp_friendlyfire.BoolValue;
	int alive = TotalPlayersAliveEnemy(friendly ? -1 : team);
	
	switch (val.tag) {
		case KeyValType_Section: {
			ConfigData condition = view_as<ConfigData>(val.cfg);
			StringMapSnapshot snap = condition.Snapshot();
			
			TFCond cond;
			int entries = snap.Length;
			for (int i; i < entries; i++) {
				int length = snap.KeyBufferSize(i) + 1;
				char[] buffer = new char[length];
				snap.GetKey(i, buffer, length);
				
				if (TranslateTFCond(buffer, cond)) {
					float duration = GetFormula(condition, buffer, alive);
					ApplyTFCondition(clients, numClients, cond, duration, additive);
				}
			}
			
			delete snap;
		}
		case KeyValType_Value: {
			char conds[16][16];
			int count = ExplodeString(val.data, ";", conds, sizeof(conds), sizeof(conds[]));
			if (count > 0) {
				for (int i = 0; i < count; i += 2) {
					TFCond cond = view_as<TFCond>(StringToInt(conds[i]));
					float duration = ParseExpr(conds[i + 1], Formula_BasicValue, alive);
					ApplyTFCondition(clients, numClients, cond, duration, additive);
				}
			}
		}
	}
}

void ApplyTFCondition(int[] clients, int numClients, TFCond cond, float duration, bool additive) {
	for (int i; i < numClients; i++) {
		if (!TF2_IsPlayerInCondition(clients[i], cond)) {
			if (duration < 0.0)
				duration = TFCondDuration_Infinite;
						
			TF2_AddCondition(clients[i], cond, duration);
		} else {
			if (!additive) {
				return;
			}
			
			float currentDuration = TF2Util_GetPlayerConditionDuration(clients[i], cond);
			TF2Util_SetPlayerConditionDuration(clients[i], cond, currentDuration + duration);
		}
	}
}

/*
void ApplyTFConditions(int[] client, int numClients, PackVal val) {
	switch (val.tag) {
		
	}
	StringMapSnapshot snap = condition.Snapshot();
	TFCond cond;
	int entries = snap.Length;
	for (int i; i < entries; i++) {
		int length = snap.KeyBufferSize(i) + 1;
		char[] buffer = new char[length];
		snap.GetKey(i, buffer, length);
		
		if (TranslateTFCond(buffer, cond)) {
			float duration = GetFormula(condition, buffer, TotalPlayersAliveEnemy(CvarFriendlyFire.BoolValue ? -1 : GetClientTeam(client)));
			ApplyTFCondition(client, cond, duration, additive);
		}
	}
	delete snap;
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
					float duration = GetFormula(condition, buffer, TotalPlayersAliveEnemy(CvarFriendlyFire.BoolValue ? -1 : GetClientTeam(client)));
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
					float duration = ParseFormula(conds[i + 1], TotalPlayersAliveEnemy(CvarFriendlyFire.BoolValue ? -1 : GetClientTeam(client)));
					ApplyTFCondition(client, cond, duration, additive);
				}
			}
		}
		case KeyValType_Null: {
			return;
		}
	}
}
*/

int TotalPlayersAliveEnemy(int team = -1) {
	int amount;
	for (int i = SpecTeam ? 0 : 2; i < sizeof(PlayersAlive); i++) {
		if (i != team)
			amount += PlayersAlive[i];
	}

	return amount;
}

float GetFormula(ConfigData cfg, const char[] key, int players, float flDefault = 0.0) {
	static char buffer[1024];
	if (!cfg.GetString(key, buffer, sizeof(buffer)))
		return flDefault;

	return ParseExpr(buffer, Formula_BasicValue, float(players));
}

void Formula_BasicValue(const char[] var_name, int var_name_len, float &f, any data) {
	if(CharToLower(var_name[0]) == 'n' || CharToLower(var_name[0]) == 'x')
		f = data;
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
