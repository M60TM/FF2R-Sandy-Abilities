/*
"1"
{
	"name"			"Modify"
	"name_en"		"Modify"
	
	"description_en"	""
	
	"ff2r_difficulty_reward"
	{
		"refund"	"0.25"
	}
}
*/

#include <sourcemod>
#include <cfgmap>
#include <ff2r>

#include <tf2_stocks>
#include <freak_fortress_2>

#pragma semicolon 1
#pragma newdecls required

#define MAXTF2PLAYERS MAXPLAYERS + 1

enum struct DifficultyReward {
	bool Enabled;
	int Refund;
	
	void Reset() {
		this.Enabled = false;
		this.Refund = 0;
	}
}

ConVar g_CvarCompanionPoint;
int QueuePoints[MAXTF2PLAYERS];
DifficultyReward PlayerReward[MAXTF2PLAYERS];

public Plugin myinfo = {
	name = "[FF2R] Difficulty Rewards",
	author = "Sandy",
	description = "Try harder!",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	g_CvarCompanionPoint = CreateConVar("ff2r_difficulty_companion_point", "0", "If you choose not to reset companion's point, enable this.", 0, true, 0.0, true, 1.0);
	
	HookEvent("teamplay_round_win", OnRoundEnd);
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
	int winningTeam = event.GetInt("team");
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			if (GetClientTeam(client) == winningTeam && !FF2R_GetClientMinion(client) && PlayerReward[client].Enabled) {
				BossData boss = new BossData(client);
				if (boss) {
					if (g_CvarCompanionPoint.BoolValue && boss.GetBool("blocked") && boss.GetKeyValType("group") != KeyValType_Null) {
						FF2_SetQueuePoints(client, QueuePoints[client] + PlayerReward[client].Refund);
					} else {
						FF2_SetQueuePoints(client, PlayerReward[client].Refund);
					}
				} else {	// This couldn't happen..but
					FF2_SetQueuePoints(client, PlayerReward[client].Refund);
				}
			}
		}
		QueuePoints[client] = FF2_GetQueuePoints(client);
		PlayerReward[client].Reset();
	}
}

public void FF2R_OnBossModifier(int client, ConfigData cfg) {
	if (!PlayerReward[client].Enabled) {
		PlayerReward[client].Enabled = true;
	
		int queue = QueuePoints[client];
		PlayerReward[client].Refund = RoundFloat(cfg.GetFloat("refund") * queue);
	}
}