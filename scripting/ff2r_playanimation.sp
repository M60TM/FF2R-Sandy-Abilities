/*
	"intro_playanimation"
	{
		"activity"	"ACT_TRANSITION"					// If type is 1, sequence name or activity name. type is 2, activity name.
		"type"		"2"									// 1 - Force Sequence 2 - Play Gesture
		"plugin_name"	"ff2r_playanimation"
	}
	
	"rage_playanimation"
	{
		"slot"		"0"									// Ability Slot
		"activity"	"ACT_MP_GESTURE_VC_HANDMOUTH_ITEM1" // If type is 1, sequence name or activity name. type is 2, activity name.
		"type"		"2"									// 1 - Force Sequence 2 - Play Gesture
		"plugin_name"	"ff2r_playanimation"
	}
*/

#include <sourcemod>
#include <sdktools>
#include <cfgmap>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required

Handle SDKCall_PlaySpecificSequence;
Handle SDKCall_PlayGesture;

ArrayList AnimationTimerList[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[FF2R] Play Animation",
	author = "Sandy",
	description = "Let them dance",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	GameData data = new GameData("ff2r.sandy");
	if (data == null) {
		SetFailState("Missing ff2r.sandy.txt");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CTFPlayer::PlaySpecificSequence");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	SDKCall_PlaySpecificSequence = EndPrepSDKCall();
	if (!SDKCall_PlaySpecificSequence)
		LogMessage("Failed to create call: CTFPlayer::PlaySpecificSequence");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CTFPlayer::PlayGesture");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	SDKCall_PlayGesture = EndPrepSDKCall();
	if (!SDKCall_PlayGesture)
		LogMessage("Failed to create call: CTFPlayer::PlayGesture");
	
	delete data;
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!AnimationTimerList[client]) {
		AnimationTimerList[client] = new ArrayList();
	}
	
	if (setup) {
		AbilityData ability = cfg.GetAbility("intro_playanimation");
		if (ability.IsMyPlugin()) {
			char animation[PLATFORM_MAX_PATH];
			ability.GetString("activity", animation, sizeof(animation));
				
			int type = ability.GetInt("type", 2);
			
			DataPack pack;
			AnimationTimerList[client].Push(CreateDataTimer(ability.GetFloat("duration"), Timer_PlayAnimation, pack, TIMER_FLAG_NO_MAPCHANGE));
			pack.WriteCell(client);
			pack.WriteString(animation);
			pack.WriteCell(type);
			pack.Reset();
		}
	}
}

public void FF2R_OnBossRemoved(int client) {
	int length = AnimationTimerList[client].Length;
	for (int i; i < length; i++)
	{
		Handle timer = AnimationTimerList[client].Get(i);
		delete timer;
	}
	
	delete AnimationTimerList[client];
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "rage_playanimation") && cfg.IsMyPlugin()) {
		char animation[PLATFORM_MAX_PATH];
		cfg.GetString("activity", animation, sizeof(animation));
		
		int type = cfg.GetInt("type", 2);
		
		DataPack pack;
		AnimationTimerList[client].Push(CreateDataTimer(cfg.GetFloat("duration"), Timer_PlayAnimation, pack, TIMER_FLAG_NO_MAPCHANGE));
		pack.WriteCell(client);
		pack.WriteString(animation);
		pack.WriteCell(type);
		pack.Reset();
	}
}

public Action Timer_PlayAnimation(Handle timer, DataPack pack) {
	int client = pack.ReadCell();
	if (IsClientInGame(client)) {
		AnimationTimerList[client].Erase(AnimationTimerList[client].FindValue(timer));
		if (IsPlayerAlive(client)) {
			char animation[PLATFORM_MAX_PATH];
			pack.ReadString(animation, sizeof(animation));
			int type = pack.ReadCell();
			SetAnimation(client, animation, type);
		}
	}
	
	return Plugin_Continue;
}

stock void SetAnimation(int client, const char[] animation, int animationType) {
	switch(animationType) {
		case 1: {
			SDKCall(SDKCall_PlaySpecificSequence, client, animation);
		}
		case 2: {
			SDKCall(SDKCall_PlayGesture, client, animation);
		}
	}
}