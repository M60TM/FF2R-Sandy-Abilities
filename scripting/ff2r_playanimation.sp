/*
	"intro_playsequence"
	{
		"delay"			"0.0"
		"animation"		"taunt03"	// sequence name
		
		"plugin_name"	"ff2r_playanimation"
	}
	
	"intro_playgesture"
	{
		"delay"			"0.0"
		"animation"		"ACT_MP_GESTURE_VC_HANDMOUTH_ITEM1"	// activity name
		
		"plugin_name"	"ff2r_playanimation"
	}
	
	"intro_doanimationevent"
	{
		"delay"			"0.0"
		"animation"		"0"	// event index
		
		"plugin_name"	"ff2r_playanimation"
	}
	
	"rage_playsequence"
	{
		"slot"			"0"
		"delay"			"0.0"
		"animation"		"taunt03"	// sequence name
		
		"plugin_name"	"ff2r_playanimation"
	}
	
	"rage_playgesture"
	{
		"slot"			"0"
		"delay"			"0.0"
		"animation"		"ACT_MP_GESTURE_VC_HANDMOUTH_ITEM1"	// activity name
		
		"plugin_name"	"ff2r_playanimation"
	}
	
	"rage_doanimationevent"
	{
		"slot"			"0"
		"delay"			"0.0"
		"animation"		"0"	// event index
		
		"plugin_name"	"ff2r_playanimation"
	}
	
	"rage_playviewmodel"
	{
		"slot"			"0"
		"delay"			"0.0"
		"activity"		"vsh_slam_land" // sequence name or activity name
		"reset"			"true"			// Force play viewmodel animation
		
		"plugin_name"	"ff2r_playanimation"
	}
*/

#include <sourcemod>
#include <sdktools>
#include <cbasenpc>
#include <cfgmap>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required

enum PlayerAnimEvent_t {
	PLAYERANIMEVENT_ATTACK_PRIMARY,
	PLAYERANIMEVENT_ATTACK_SECONDARY,
	PLAYERANIMEVENT_ATTACK_GRENADE,
	PLAYERANIMEVENT_RELOAD,
	PLAYERANIMEVENT_RELOAD_LOOP,
	PLAYERANIMEVENT_RELOAD_END,
	PLAYERANIMEVENT_JUMP,
	PLAYERANIMEVENT_SWIM,
	PLAYERANIMEVENT_DIE,
	PLAYERANIMEVENT_FLINCH_CHEST,
	PLAYERANIMEVENT_FLINCH_HEAD,
	PLAYERANIMEVENT_FLINCH_LEFTARM,
	PLAYERANIMEVENT_FLINCH_RIGHTARM,
	PLAYERANIMEVENT_FLINCH_LEFTLEG,
	PLAYERANIMEVENT_FLINCH_RIGHTLEG,
	PLAYERANIMEVENT_DOUBLEJUMP,

	// Cancel.
	PLAYERANIMEVENT_CANCEL,
	PLAYERANIMEVENT_SPAWN,

	// Snap to current yaw exactly
	PLAYERANIMEVENT_SNAP_YAW,

	PLAYERANIMEVENT_CUSTOM,				// Used to play specific activities
	PLAYERANIMEVENT_CUSTOM_GESTURE,
	PLAYERANIMEVENT_CUSTOM_SEQUENCE,	// Used to play specific sequences
	PLAYERANIMEVENT_CUSTOM_GESTURE_SEQUENCE,

	// TF Specific. Here until there's a derived game solution to this.
	PLAYERANIMEVENT_ATTACK_PRE,
	PLAYERANIMEVENT_ATTACK_POST,
	PLAYERANIMEVENT_GRENADE1_DRAW,
	PLAYERANIMEVENT_GRENADE2_DRAW,
	PLAYERANIMEVENT_GRENADE1_THROW,
	PLAYERANIMEVENT_GRENADE2_THROW,
	PLAYERANIMEVENT_VOICE_COMMAND_GESTURE,
	PLAYERANIMEVENT_DOUBLEJUMP_CROUCH,
	PLAYERANIMEVENT_STUN_BEGIN,
	PLAYERANIMEVENT_STUN_MIDDLE,
	PLAYERANIMEVENT_STUN_END,
	PLAYERANIMEVENT_PASSTIME_THROW_BEGIN,
	PLAYERANIMEVENT_PASSTIME_THROW_MIDDLE,
	PLAYERANIMEVENT_PASSTIME_THROW_END,
	PLAYERANIMEVENT_PASSTIME_THROW_CANCEL,

	PLAYERANIMEVENT_ATTACK_PRIMARY_SUPER,

	PLAYERANIMEVENT_COUNT
};

Handle SDKCall_LookupActivity;
Handle SDKCall_PlaySpecificSequence;
Handle SDKCall_PlayGesture;
Handle SDKCall_DoAnimationEvent;

ArrayList AnimationTimerList[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[FF2R] Play Animation",
	author = "Sandy",
	description = "Let them dance",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	GameData gamedata = new GameData("ff2r.sandy");
	if (gamedata == null) {
		SetFailState("Missing ff2r.sandy.txt");
	}
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "LookupActivity");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//pStudioHdr
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);		//label
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);	//return index
	SDKCall_LookupActivity = EndPrepSDKCall();
	if (!SDKCall_LookupActivity)
		LogMessage("Failed to create call: LookupActivity");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::PlaySpecificSequence");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	SDKCall_PlaySpecificSequence = EndPrepSDKCall();
	if (!SDKCall_PlaySpecificSequence)
		LogMessage("Failed to create call: CTFPlayer::PlaySpecificSequence");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::PlayGesture");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	SDKCall_PlayGesture = EndPrepSDKCall();
	// Intended pass check sdkcall
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::DoAnimationEvent");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	SDKCall_DoAnimationEvent = EndPrepSDKCall();
	if (!SDKCall_DoAnimationEvent)
		LogMessage("Failed to create call: CTFPlayer::DoAnimationEvent");
	
	delete gamedata;
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!AnimationTimerList[client]) {
		AnimationTimerList[client] = new ArrayList();
	}
	
	if (setup) {
		AbilityData ability = cfg.GetAbility("intro_playsequence");
		if (ability.IsMyPlugin()) {
			char animation[PLATFORM_MAX_PATH];
			ability.GetString("animation", animation, sizeof(animation));
			
			DataPack pack;
			AnimationTimerList[client].Push(CreateDataTimer(ability.GetFloat("delay"), Timer_PlaySequence, pack));
			pack.WriteCell(client);
			pack.WriteString(animation);
		}
		
		ability = cfg.GetAbility("intro_playgesture");
		if (ability.IsMyPlugin()) {
			char animation[PLATFORM_MAX_PATH];
			ability.GetString("animation", animation, sizeof(animation));
			
			DataPack pack;
			AnimationTimerList[client].Push(CreateDataTimer(ability.GetFloat("delay"), Timer_PlayGesture, pack));
			pack.WriteCell(client);
			pack.WriteString(animation);
		}
		
		ability = cfg.GetAbility("intro_doanimationevent");
		if (ability.IsMyPlugin()) {
			char animation[PLATFORM_MAX_PATH];
			ability.GetString("animation", animation, sizeof(animation));
			
			DataPack pack;
			AnimationTimerList[client].Push(CreateDataTimer(ability.GetFloat("delay"), Timer_DoAnimationEvent, pack));
			pack.WriteCell(client);
			pack.WriteCell(ability.GetInt("event", view_as<int>(PLAYERANIMEVENT_CUSTOM)));
			pack.WriteString(animation);
		}
	}
}

public void FF2R_OnBossRemoved(int client) {
	int length = AnimationTimerList[client].Length;
	for (int i; i < length; i++) {
		Handle timer = AnimationTimerList[client].Get(i);
		delete timer;
	}
	
	delete AnimationTimerList[client];
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "rage_playsequence", false)) {
		char animation[PLATFORM_MAX_PATH];
		cfg.GetString("animation", animation, sizeof(animation));
		
		DataPack pack;
		AnimationTimerList[client].Push(CreateDataTimer(cfg.GetFloat("delay"), Timer_PlaySequence, pack));
		pack.WriteCell(client);
		pack.WriteString(animation);
	}
	else if (!StrContains(ability, "rage_playgesture", false)) {
		char animation[PLATFORM_MAX_PATH];
		cfg.GetString("animation", animation, sizeof(animation));
		
		DataPack pack;
		AnimationTimerList[client].Push(CreateDataTimer(cfg.GetFloat("delay"), Timer_PlayGesture, pack));
		pack.WriteCell(client);
		pack.WriteString(animation);
	}
	else if (!StrContains(ability, "rage_doanimationevent", false)) {
		char animation[PLATFORM_MAX_PATH];
		cfg.GetString("animation", animation, sizeof(animation));
		
		DataPack pack;
		AnimationTimerList[client].Push(CreateDataTimer(cfg.GetFloat("delay"), Timer_DoAnimationEvent, pack));
		pack.WriteCell(client);
		pack.WriteCell(cfg.GetInt("event", view_as<int>(PLAYERANIMEVENT_CUSTOM)));
		pack.WriteString(animation);
	}
	else if (!StrContains(ability, "rage_playviewmodel", false)) {
		char animation[PLATFORM_MAX_PATH];
		cfg.GetString("activity", animation, sizeof(animation));
		
		DataPack pack;
		AnimationTimerList[client].Push(CreateDataTimer(cfg.GetFloat("delay"), Timer_PlayViewmodel, pack));
		pack.WriteCell(client);
		pack.WriteString(animation);
		pack.WriteCell(cfg.GetBool("reset", true));
	}
}

public Action Timer_PlaySequence(Handle timer, DataPack pack) {
	pack.Reset();
	
	int client = pack.ReadCell();
	if (IsClientInGame(client)) {
		AnimationTimerList[client].Erase(AnimationTimerList[client].FindValue(timer));
		if (IsPlayerAlive(client)) {
			char animation[PLATFORM_MAX_PATH];
			pack.ReadString(animation, sizeof(animation));
			SDKCall_CTFPlayer_PlaySpecificSequence(client, animation);
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_PlayGesture(Handle timer, DataPack pack) {
	pack.Reset();
	
	int client = pack.ReadCell();
	if (IsClientInGame(client)) {
		AnimationTimerList[client].Erase(AnimationTimerList[client].FindValue(timer));
		if (IsPlayerAlive(client)) {
			char animation[PLATFORM_MAX_PATH];
			pack.ReadString(animation, sizeof(animation));
			SDKCall_CTFPlayer_PlayGesture(client, animation);
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_DoAnimationEvent(Handle timer, DataPack pack) {
	pack.Reset();
	
	int client = pack.ReadCell();
	if (IsClientInGame(client)) {
		AnimationTimerList[client].Erase(AnimationTimerList[client].FindValue(timer));
		if (IsPlayerAlive(client)) {
			PlayerAnimEvent_t event = view_as<PlayerAnimEvent_t>(pack.ReadCell());
			
			int data = 0;
			char animation[PLATFORM_MAX_PATH];
			if (pack.ReadString(animation, sizeof(animation))) {
				data = SDKCall_Studio_LookupActivity(client, animation);
				if (data == -1) {
					data = CBaseAnimating(client).LookupSequence(animation);
					if (data == -1)
						data = 0;
				}
			}
			
			SDKCall_CTFPlayer_DoAnimationEvent(client, event, data);
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_PlayViewmodel(Handle timer, DataPack pack) {
	pack.Reset();
	
	int client = pack.ReadCell();
	if (IsClientInGame(client)) {
		AnimationTimerList[client].Erase(AnimationTimerList[client].FindValue(timer));
		if (IsPlayerAlive(client)) {
			char animation[PLATFORM_MAX_PATH];
			pack.ReadString(animation, sizeof(animation));
			
			if (pack.ReadCell()) {
				SetViewmodelAnimation(client, animation);
			}
			else {
				PlayViewmodelAnimation(client, animation);
			}
		}
	}
	
	return Plugin_Continue;
}

stock void SetViewmodelAnimation(int client, const char[] activity) {
	char buffer[PLATFORM_MAX_PATH];
	Format(buffer, sizeof(buffer), "self.ResetSequence(self.LookupSequence(`%s`))", activity);
	SetVariantString(buffer);
	AcceptEntityInput(GetEntPropEnt(client, Prop_Send, "m_hViewModel"), "RunScriptCode");
}

stock void PlayViewmodelAnimation(int client, const char[] activity) {
	char buffer[PLATFORM_MAX_PATH];
	Format(buffer, sizeof(buffer), "local sequenceId = self.LookupSequence(`%s`);if (sequenceId != self.GetSequence()) self.SetSequence(sequenceId)", activity);
	SetVariantString(buffer);
	AcceptEntityInput(GetEntPropEnt(client, Prop_Send, "m_hViewModel"), "RunScriptCode");
}

int SDKCall_Studio_LookupActivity(int entity, const char[] activityName) {
	Address modelPtr = CBaseAnimating(entity).GetModelPtr();
	if (modelPtr == Address_Null)
		return -1;
	
	return SDKCall(SDKCall_LookupActivity, modelPtr, activityName);
}

void SDKCall_CTFPlayer_DoAnimationEvent(int client, PlayerAnimEvent_t event, int data = 0) {
	if (SDKCall_DoAnimationEvent)
		SDKCall(SDKCall_DoAnimationEvent, client, event, data);
}

void SDKCall_CTFPlayer_PlayGesture(int client, const char[] gestureName) {
	if (SDKCall_PlayGesture) {
		SDKCall(SDKCall_PlayGesture, client, gestureName);
	}
	else {
		int data = SDKCall_Studio_LookupActivity(client, gestureName);
		if (data == -1) {
			data = CBaseAnimating(client).LookupSequence(gestureName);
			SDKCall_CTFPlayer_DoAnimationEvent(client, PLAYERANIMEVENT_CUSTOM_GESTURE_SEQUENCE, data);
		}
		else {
			SDKCall_CTFPlayer_DoAnimationEvent(client, PLAYERANIMEVENT_CUSTOM_GESTURE, data);
		}
	}
}

void SDKCall_CTFPlayer_PlaySpecificSequence(int client, const char[] sequenceName) {
	if (SDKCall_PlaySpecificSequence)
		SDKCall(SDKCall_PlaySpecificSequence, client, sequenceName);
}