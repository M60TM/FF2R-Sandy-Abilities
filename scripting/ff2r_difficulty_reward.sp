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
#include <dhooks>
#include <cfgmap>
#include <ff2r>
#include <morecolors>

#pragma semicolon 1
#pragma newdecls required

enum struct DifficultyReward {
	bool Enabled;
	int Refund;
	
	void Reset() {
		this.Enabled = false;
		this.Refund = 0;
	}
}

native int FF2_GetQueuePoints(int client);

forward Action FF2_OnAddQueuePoints(int add_points[MAXPLAYERS + 1]);

int WinningTeam;
int QueuePoints[MAXPLAYERS + 1];
DifficultyReward PlayerReward[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[FF2R] Difficulty Rewards",
	author = "B14CK04K",
	description = "Try harder!",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	LoadTranslations("ff2r_difficulty_reward.phrases");
	
	GameData gamedata = new GameData("tf2.gamerules");
	if (gamedata == null) {
		SetFailState("Missing tf2.gamerules.txt");
	}
	
	DynamicDetour dtRulesStateEnter = DynamicDetour.FromConf(gamedata, "CTeamplayRoundBasedRules::State_Enter");
	dtRulesStateEnter.Enable(Hook_Pre, Detour_RulesStateEnter);
	
	delete gamedata;
	
	HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_Pre);
}

MRESReturn Detour_RulesStateEnter(DHookParam params) {
	RoundState newState = view_as<RoundState>(params.Get(1));
	
	if (newState == RoundState_Preround) {
		for (int client = 1; client <= MaxClients; client++) {
			QueuePoints[client] = FF2_GetQueuePoints(client);
		}
	}
	
	return MRES_Ignored;
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
	WinningTeam = event.GetInt("team");
}

public void FF2R_OnBossModifier(int client, ConfigData cfg) {
	if (!PlayerReward[client].Enabled) {
		PlayerReward[client].Enabled = true;
		
		int queue = QueuePoints[client];
		PlayerReward[client].Refund = RoundFloat(cfg.GetFloat("refund") * queue);
	}
}

public Action FF2_OnAddQueuePoints(int add_points[MAXPLAYERS + 1]) {
	bool changed = false;
	
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			if (GetClientTeam(client) == WinningTeam && !FF2R_GetClientMinion(client) && PlayerReward[client].Enabled) {
				add_points[client] += PlayerReward[client].Refund;
				CPrintToChat(client, "{blue}[FF2R]{default} %T", "Queue Point Refund", client, add_points[client]);
				changed = true;
			}
		}
		PlayerReward[client].Reset();
	}
	
	return changed ? Plugin_Changed : Plugin_Continue;
}