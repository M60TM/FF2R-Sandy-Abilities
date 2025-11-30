#pragma semicolon 1
#include <sourcemod>

#include <tf2_stocks>
#include <sdkhooks>
#include <dhooks>
#include <cfgmap>
#include <ff2r>
#include <tf_ontakedamage>

#pragma newdecls required

#define NULL_SOUND "misc/null.wav"

enum struct HHHTrait {
	bool Enabled;
	float Speed;
	int MaxHeads;
	
	void Reset() {
		this.Enabled = false;
		this.Speed = 0.0;
		this.MaxHeads = 0;
	}
	
	void Parse(ConfigData cfg) {
		if (cfg != null) {
			this.Enabled = true;
			this.Speed = cfg.GetFloat("speed", 0.02);
			this.MaxHeads = cfg.GetInt("heads", 16);
		}
	}
}

native void FF2_SetClientGlow(int client, float add, float set=-1.0);

DynamicHook DHookSwordHealthMod;
DynamicHook DHookSwordSpeedMod;

HHHTrait HHHTraits[MAXPLAYERS + 1];

bool PlayerScaled[MAXPLAYERS + 1];

bool FootstepReplace[MAXPLAYERS + 1];
bool FootstepRight[MAXPLAYERS + 1];

#include "freak_fortress_2/subplugin.sp"

public Plugin myinfo = {
	name = "[FF2R] HHH.jr Abilities",
	author = "B14CK04K",
	description = "",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	AddNormalSoundHook(SoundHook);
	
	GameData gamedata = new GameData("ff2r.sandy");
	if (!gamedata) {
		SetFailState("Failed to load gamedata (ff2r.sandy.txt)");
	}
	
	DHookSwordHealthMod = DynamicHook.FromConf(gamedata, "CTFSword::GetSwordHealthMod()");
	DHookSwordSpeedMod = DynamicHook.FromConf(gamedata, "CTFSword::GetSwordSpeedMod()");
	
	delete gamedata;
	
	Subplugin_PluginStart();
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (!StrContains(classname, "tf_weapon_sword", false)) {
		OnSwordCreated(entity);
	}
}

void FF2R_PluginLoaded() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			BossData cfg = FF2R_GetBossData(client);
			if (cfg){
				FF2R_OnBossCreated(client, cfg, false);
				FF2R_OnBossEquipped(client, true);
			}
		}
	}
	
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "tf_weapon_sword")) != -1) {
		OnSwordCreated(entity);
	}
}

static void OnSwordCreated(int sword) {
	DHookSwordHealthMod.HookEntity(Hook_Post, sword, DHook_SwordHealthMod);
	DHookSwordSpeedMod.HookEntity(Hook_Post, sword, DHook_SwordSpeedMod);
}

public void OnMapStart() {
	PrecacheSound("ui/halloween_boss_tagged_other_it.wav");
}

public void OnPluginEnd() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			if (FF2R_GetBossData(client))
				FF2R_OnBossRemoved(client);
		}
	}
}

public void OnLibraryAdded(const char[] name) {
	Subplugin_LibraryAdded(name);
}

public void OnLibraryRemoved(const char[] name) {
	Subplugin_LibraryRemoved(name);
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!setup || FF2R_GetGamemodeType() != 2) {
		AbilityData ability = cfg.GetAbility("special_hhh_traits");
		if (ability.IsMyPlugin()) {
			HHHTraits[client].Parse(ability);
		}
		
		FootstepReplace[client] = ((ability = cfg.GetAbility("special_footstep_replace")) && ability.IsMyPlugin());
	}
}

public void FF2R_OnBossEquipped(int client, bool weapons) {
	if (weapons && !PlayerScaled[client]) {
		float scale = FF2R_GetBossData(client).GetFloat("scale", 1.0);
		if (scale > 0.0 && scale != 1.0) {
			PlayerScaled[client] = true;
			SetEntPropFloat(client, Prop_Send, "m_flModelScale", scale);
			UpdatePlayerHitbox(client, scale);
		}
	}
}

public void FF2R_OnBossRemoved(int client) {
	HHHTraits[client].Reset();
	FootstepReplace[client] = false;
	if (PlayerScaled[client]) {
		PlayerScaled[client] = false;
		if (IsPlayerAlive(client)) {
			SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.0);
			UpdatePlayerHitbox(client, 1.0);
		}
	}
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "rage_tag_it", false)) {
		TagIT(client, cfg);
	}
}

public Action TF2_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom, CritType &critType) {
	if (victim != attacker && attacker > 0 && attacker <= MaxClients && HHHTraits[attacker].Enabled && !FF2R_GetBossData(victim)) {
		float flDamage = float(GetClientHealth(victim)) * 0.8;
		if (flDamage > damage) {
			damage = flDamage;
		}
		
		// Prevent to use knockback to escape dangerous situation
		damagetype |= DMG_PREVENT_PHYSICS_FORCE;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

MRESReturn DHook_SwordHealthMod(int sword, DHookReturn ret) {
	if (GetHHHDecapitationMode(sword)) {
		ret.Value = 0;
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

MRESReturn DHook_SwordSpeedMod(int sword, DHookReturn ret) {
	float speed = 1.0;
	if (GetHHHDecapitationMode(sword, speed)) {
		ret.Value = speed;
		return MRES_Supercede;
	}
	return MRES_Ignored;
}

void TagIT(int client, ConfigData cfg) {
	int team = GetClientTeam(client);
	
	int victims;
	int[] victim = new int[MaxClients - 1];
	for (int i = 1; i <= MaxClients; i++) {
		if (client == i || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) == team) {
			continue;
		}
		
		victim[victims++] = i;
	}
	
	// Find deadliest person
	if (victims) {
		int target = victim[0];
		for (int i = 1; i < victims; i++) {
			if (FF2R_GetClientScore(victim[i]) > FF2R_GetClientScore(target)) {
				target = victim[i];
			}
		}
		
		float duration = cfg.GetFloat("duration", 30.0);
		PrintCenterText(target, "당신이 술래입니다!");
		PrintCenterText(client, "%N 님이 술래입니다!", target);
		
		int clients[2];
		clients[0] = client; clients[1] = target;
		EmitSound(clients, 2, "ui/halloween_boss_tagged_other_it.wav");
		
		TF2_AddCondition(target, TFCond_MarkedForDeath, duration);
		FF2_SetClientGlow(target, 0.0, duration);
	}
}

bool GetHHHDecapitationMode(int weapon, float &flSpeed = 1.0) {
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return false;
	
	if (HHHTraits[client].Enabled) {
		int nDecapitations = GetEntProp(client, Prop_Send, "m_iDecapitations");
		if (HHHTraits[client].MaxHeads < nDecapitations)
			nDecapitations = HHHTraits[client].MaxHeads;
		
		flSpeed += (nDecapitations * HHHTraits[client].Speed);
		return true;
	}
	
	return false;
}

public Action SoundHook(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (volume == 0.0 || volume == 0.9997) {
		return Plugin_Continue;
	}
	
	if (entity < 1 || entity > MaxClients || !IsClientInGame(entity) || IsClientSourceTV(entity) || IsClientReplay(entity)) {
		return Plugin_Continue;
	}
	
	if (!FootstepReplace[entity]) {
		return Plugin_Continue;
	}
	
	if (TF2_IsPlayerInCondition(entity, TFCond_Taunting)) {
		return Plugin_Continue;
	}
	
	if (StrContains(sample, "player/footsteps/", false) == -1) {
		return Plugin_Continue;
	}
	
	if (StrContains(sample, NULL_SOUND, false) != -1) {
		return Plugin_Continue;
	}
	
	strcopy(sample, sizeof(sample), NULL_SOUND);
	
	int foot;
	if (FootstepRight[entity]) {
		foot = LookupEntityAttachment(entity, "foot_R");
		FootstepRight[entity] = false;
	}
	else {
		foot = LookupEntityAttachment(entity, "foot_L");
		FootstepRight[entity] = true;
	}
	
	float pos[3], ang[3];
	if (foot && GetEntityAttachment(entity, foot, pos, ang)) {
		FF2R_EmitBossSoundToAll("sound_footstep", entity, _, entity, SNDCHAN_STATIC, _, _, 1.0, _, _, pos);
	}
	else {
		FF2R_EmitBossSoundToAll("sound_footstep", entity, _, entity, SNDCHAN_STATIC, _, _, 1.0);
	}
	
	return Plugin_Stop;
}

stock void UpdatePlayerHitbox(int client, float scale) {
	float vecScaledPlayerMin[3], vecScaledPlayerMax[3];
	GetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMins", vecScaledPlayerMin);
	GetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMaxs", vecScaledPlayerMax);
	ScaleVector(vecScaledPlayerMin, scale);
	ScaleVector(vecScaledPlayerMax, scale);
	SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMins", vecScaledPlayerMin);
	SetEntPropVector(client, Prop_Send, "m_vecSpecifiedSurroundingMaxs", vecScaledPlayerMax);
}