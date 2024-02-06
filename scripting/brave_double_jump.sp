/*
	"special_double_jump"
	{
		"velocity"		"300.0"
		"upward"		"850.0"
		"delay"			"10.0"
		"cooldown"		"7.5"
		"forward_power"	"1.25"
		"upward_power"	"1.4"
		
		"plugin_name"	"brave_double_jump"
	}
	
	"sound_brave_jump"
	{
		"saxton_hale/saxton_hale_132_jump_1.wav"	""
		"saxton_hale/saxton_hale_132_jump_2.wav"	""
		"saxton_hale/saxton_hale_responce_jump1.wav"	""
	}
 */

#include <sourcemod>
#include <dhooks_gameconf_shim>
#include <tf2_stocks>
#include <cfgmap>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required

#define MAXTF2PLAYERS MAXPLAYERS + 1

#define TF_PLAYER_ENEMY_BLASTED_ME (1 << 2)

Handle SyncHud;

int BlastJumpStateOffset = -1;

bool BraveJump[MAXTF2PLAYERS];
bool BraveJumping[MAXTF2PLAYERS];

public Plugin myinfo = {
	name = "[FF2R] Brave Double Jump",
	author = "Sandy",
	description = "Brave Jump with cooltime.",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	LoadTranslations("ff2r_doublejump.phrases");
	
	GameData data = new GameData("ff2");
	if (data == null) {
		SetFailState("Failed to load GameData(ff2.txt)");
	} else if (!ReadDHooksDefinitions("ff2")) {
		SetFailState("Failed to read GameData(ff2.txt)");
	}
	
	DynamicDetour dynDetour_PlayerCanAirDash = GetDHooksDetourDefinition(data, "CTFPlayer::CanAirDash");
	dynDetour_PlayerCanAirDash.Enable(Hook_Post, DynDetour_PlayerCanAirDashPost);
	
	BlastJumpStateOffset = data.GetOffset("CTFPlayer::m_iBlastJumpState");
	if(BlastJumpStateOffset == -1)
		LogError("[Gamedata] Could not find CTFPlayer::m_iBlastJumpState");
	
	ClearDHooksDefinitions();
	delete data;
	
	SyncHud = CreateHudSynchronizer();
	
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			BossData cfg = FF2R_GetBossData(client);
			if (cfg) {
				FF2R_OnBossCreated(client, cfg, false);
			}
		}
	}
}

public void FF2R_OnBossCreated(int client, BossData boss, bool setup) {
	if (!setup || FF2R_GetGamemodeType() != 2) {
		if (!BraveJump[client]) {
			AbilityData ability = boss.GetAbility("special_double_jump");
			if (ability.IsMyPlugin()) {
				BraveJump[client] = true;
				BraveJumping[client] = false;
				ability.SetFloat("delay", GetGameTime() + ability.GetFloat("delay", 5.0));
			}
		}
	}
}

public void FF2R_OnBossRemoved(int client) {
	BraveJump[client] = false;
	BraveJumping[client] = false;
}

public void OnPlayerRunCmdPost(int client, int buttons) {
	if (BraveJump[client]) {
		if (BraveJumping[client]) {
			if (IsPlayerAlive(client) && (GetEntityFlags(client) & FL_ONGROUND)) {
				BraveJumping[client] = false;
				TF2_RemoveCondition(client, TFCond_BlastJumping);
			}
		}
		
		BossData boss = FF2R_GetBossData(client);
		if (IsPlayerAlive(client) && boss) {
			AbilityData ability = boss.GetAbility("special_double_jump");
			if (ability && !(buttons & IN_SCORE)) {
				float gameTime = GetGameTime();
				if (gameTime > ability.GetFloat("hudin")) {
					ability.SetFloat("hudin", gameTime + 0.09);
					
					SetGlobalTransTarget(client);
					
					float delay = ability.GetFloat("delay");
					
					if (delay < gameTime) {
						SetHudTextParams(-1.0, 0.88, 0.1, 255, 255, 255, 255);
						ShowSyncHudText(client, SyncHud, "%t", "Double Jump Ready");
					} else {
						SetHudTextParams(-1.0, 0.88, 0.1, 255, 64, 64, 255);
						ShowSyncHudText(client, SyncHud, "%t", "Double Jump Not Ready", delay - gameTime);
					}
				}
			}
		}
	}
}

MRESReturn DynDetour_PlayerCanAirDashPost(int client, DHookReturn ret) {
	// Double Double Jump? Hell no.
	if (ret.Value) {
		return MRES_Ignored;
	}
	
	RequestFrame(NextFrame_DoubleJump, GetClientUserId(client));
	
	return MRES_Ignored;
}

public void NextFrame_DoubleJump(int userid) {
	int client = GetClientOfUserId(userid);
	if (!client) {
		return;
	}
	
	if (!BraveJump[client]) {
		return;
	}
	
	BossData boss = FF2R_GetBossData(client);
	if (boss) {
		AbilityData ability = boss.GetAbility("special_double_jump");
		if (ability.IsMyPlugin()) {
			float gameTime = GetGameTime();
			if (ability.GetFloat("delay") < gameTime) {
				float velocity = ability.GetFloat("velocity", 300.0);
				
				float angles[3], fwd[3], right[3];
				GetClientEyeAngles(client, angles);
				GetAngleVectors(angles, fwd, right, NULL_VECTOR);
				
				fwd[2] = 0.0;
				NormalizeVector(fwd, fwd);
				
				right[2] = 0.0;
				NormalizeVector(right, right);
				
				float newVel[3];
				newVel[0] = fwd[0];
				newVel[1] = fwd[1];
				NormalizeVector(newVel, newVel);
				ScaleVector(newVel, velocity);
				ScaleVector(newVel, VelBasedOnLowAngle(angles[0], ability.GetFloat("forward_power", 1.25)));
				
				newVel[2] = ability.GetFloat("upward", 700.0) * VelBasedOnHighAngle(angles[0], ability.GetFloat("upward_power", 1.4));
				
				float curVel[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", curVel);
				if (curVel[2] < velocity)
					curVel[2] = 0.0;
						
				AddVectors(newVel, curVel, newVel);
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, newVel);
				
				SetEntProp(client, Prop_Send, "m_bJumping", true);
				if (BlastJumpStateOffset != -1) {
					SetEntData(client, BlastJumpStateOffset, TF_PLAYER_ENEMY_BLASTED_ME);
				}
				TF2_AddCondition(client, TFCond_BlastJumping, _, client);
				
				BraveJumping[client] = true;
				
				ability.SetFloat("delay", gameTime + ability.GetFloat("cooldown"));
				ability.SetFloat("hudin", 0.0);
				
				FF2R_EmitBossSoundToAll("sound_brave_jump", client, _, client, _, SNDLEVEL_TRAFFIC);
			}
		}
	}
}

stock float VelBasedOnHighAngle(float angle, float multi) {
	float result = 1.0;
	if (-90.0 <= angle < -30.0) {
		result = result + ((multi - result) * (-angle / 90.0));
	}
	
	return result;
}

stock float VelBasedOnLowAngle(float angle, float multi) {
	float result = 1.0;
	if (-60.0 <= angle < 0.0) {
		result = result + ((multi - result) * (1 - (-angle / 90.0)));
	}
	
	return result;
}