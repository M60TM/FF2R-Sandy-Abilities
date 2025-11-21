/*
	"special_saxton_hale"	// Used for kill icon change
	{
		"plugin_name"	"ff2r_saxton_mobilities"
	}
*/
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2attributes>
#include <tf2_another_utils>

#include <stocksoup/tf/tempents_stocks>

#pragma semicolon 1
#pragma newdecls required

#include "freak_fortress_2/subplugin.sp"
#include "ff2r_saxton_mobilities/sdktools.sp"
#include "ff2r_saxton_mobilities/brave_jump.sp"
#include "ff2r_saxton_mobilities/charge_dash.sp"
#include "ff2r_saxton_mobilities/mighty_slam.sp"

#define PLUGIN_VERSION	"Custom"

#define FAR_FUTURE				100000000.0

bool SaxtonHaleEnabled[MAXPLAYERS + 1];

public Plugin myinfo = {
	name		=	"Freak Fortress 2: Rewrite - Saxton Mobilities",
	author		=	"B14CK04K",
	description	=	"Yet another saxton ability plugin",
	version		=	PLUGIN_VERSION,
	url			=	""
}

public void OnPluginStart() {
	LoadTranslations("ff2_rewrite.phrases");
	LoadTranslations("ff2r_saxton_mobilities.phrases");
	
	SDKCall_Setup();
	
	GameData gamedata = new GameData("ff2");
	
	DynamicDetour detourCanAirDash = DynamicDetour.FromConf(gamedata, "CTFPlayer::CanAirDash");
	if (detourCanAirDash)
		detourCanAirDash.Enable(Hook_Post, CanAirDashPost);
	
	delete gamedata;
	
	ChargeDash_OnPluginStart();
	MightySlam_OnPluginStart();
	BraveJump_OnPluginStart();
	
	HookEvent("player_death", Events_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("object_destroyed", Events_ObjectDestroyedPre, EventHookMode_Pre);
	
	Subplugin_PluginStart();
}

void FF2R_PluginLoaded() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			BossData cfg = FF2R_GetBossData(client);
			if (cfg) {
				FF2R_OnBossCreated(client, cfg, false);
			}
		}
	}
}

public void OnPluginEnd() {
	OnMapEnd();
	
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			if (FF2R_GetBossData(client))
				FF2R_OnBossRemoved(client);
		}
	}
}

public void OnMapStart() {
	PrecacheSound(CHARGEDASH_CHARGESOUND);
}

public void OnMapEnd() {
	ChargeDash_RemoveCustomDamage();
	MightySlam_RemoveCustomDamage();
}

public void OnLibraryAdded(const char[] name) {
	Subplugin_LibraryAdded(name);
}

public void OnLibraryRemoved(const char[] name) {
	Subplugin_LibraryRemoved(name);
}

public void OnClientDisconnect(int client) {
	MightySlam_OnClientDisconnected(client);
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3]) {
	BraveJump_OnPlayerRunCmdPost(client, buttons);
	ChargeDash_OnPlayerRunCmdPost(client, buttons);
	MightySlam_OnPlayerRunCmdPost(client, buttons, angles);
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!setup || FF2R_GetGamemodeType() != 2) {
		AbilityData ability;
		if (!SaxtonHaleEnabled[client]) {
			ability = cfg.GetAbility("special_saxton_hale");
			if (ability.IsMyPlugin()) {
				SaxtonHaleEnabled[client] = true;
			}
		}
		
		BraveJump_OnBossCreated(client, cfg);
		ChargeDash_OnBossCreated(client, cfg);
		MightySlam_OnBossCreated(client, cfg);
	}
}

public void FF2R_OnBossRemoved(int client) {
	SaxtonHaleEnabled[client] = false;
	
	MightySlam_OnBossRemoved(client);
	ChargeDash_OnBossRemoved(client);
	BraveJump_OnBossRemoved(client);
}

Action Events_PlayerDeathPre(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (victim != attacker && attacker > 0 && attacker <= MaxClients && SaxtonHaleEnabled[attacker]) {
		char buffer[64];
		event.GetString("weapon", buffer, sizeof(buffer));
		int customkill = event.GetInt("customkill");
		int damagetype = event.GetInt("damagebits");
		if ((!StrContains(buffer, "hale_")) || customkill == TF_CUSTOM_SUICIDE || damagetype == DMG_GENERIC) {
			return Plugin_Continue;
		}
		else if (customkill == TF_CUSTOM_TAUNT_HIGH_NOON) {
			event.SetString("weapon_logclassname", "hale_taunt");
			event.SetString("weapon", "hale_taunt");
		}
		else if (damagetype & DMG_CRIT) {
			event.SetString("weapon_logclassname", "hale_megapunch");
			event.SetString("weapon", "hale_megapunch");
		}
		else {
			event.SetString("weapon_logclassname", "hale_punch");
			event.SetString("weapon", "hale_punch");
		}
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

Action Events_ObjectDestroyedPre(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (attacker < 1 || attacker > MaxClients) {
		return Plugin_Continue;
	}
	
	if (SaxtonHaleEnabled[attacker]) {
		char buffer[64];
		event.GetString("weapon", buffer, sizeof(buffer));
		if ((!StrContains(buffer, "hale_"))) {
			return Plugin_Continue;
		}
		else if (event.GetInt("customkill") == TF_CUSTOM_TAUNT_HIGH_NOON) {
			event.SetString("weapon_logclassname", "hale_taunt");
			event.SetString("weapon", "hale_taunt");
		}
		else {
			event.SetString("weapon_logclassname", "hale_punch");
			event.SetString("weapon", "hale_punch");
		}
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

MRESReturn CanAirDashPost(int client, DHookReturn ret) {
	// Double Double Jump? Hell no.
	if (ret.Value) {
		return MRES_Ignored;
	}
	
	RequestFrame(BraveJumpFrame, GetClientUserId(client));
	
	return MRES_Ignored;
}

/*
void DoDamageChargeDash(int client, const float pos[3], float radius, float damage) {
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	int inflictor = EntRefToEntIndex(CustomDamageChargeDashRef);
	inflictor = inflictor != INVALID_ENT_REFERENCE ? inflictor : client;
	
	static float targetPos[3];
	int entity = -1;
	while ((entity = FindEntityInSphere(entity, pos, radius)) != -1) {
		if (client != entity && IsEntityCombatCharacter(entity)) {
			if (0 < entity <= MaxClients) {
				if (HitByChargeDash[client][entity]) {
					continue;
				}
				
				HitByChargeDash[client][entity] = true;
				
				float angles[3], fwd[3];
				TF2Util_EntityWorldSpaceCenter(entity, targetPos);
				GetVectorAnglesTwoPoints(pos, targetPos, angles);
				GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);
				
				fwd[0] *= 1250.0;
				fwd[1] *= 1250.0;
				fwd[2] = 425.0;
				
				TE_SetupTFParticleEffect("taunt_headbutt_impact_stars", targetPos);
				TE_SendToAll();
				
				SDKHooks_TakeDamage(entity, inflictor, client, damage, DMG_BURN|DMG_PREVENT_PHYSICS_FORCE, weapon, .bypassHooks = false);
				
				TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, fwd);
			} else {
				TF2Util_EntityWorldSpaceCenter(entity, targetPos);
				
				TE_SetupTFParticleEffect("taunt_headbutt_impact_stars", targetPos);
				TE_SendToAll();
				
				SDKHooks_TakeDamage(entity, inflictor, client, GetEntProp(entity, Prop_Data, "m_iMaxHealth") * 4.0, DMG_BURN|DMG_PREVENT_PHYSICS_FORCE, weapon, .bypassHooks = false);
			}
		}
	}
}
*/

stock int MakeInfoTarget(const char[] classname) {
	int target = CreateEntityByName("info_target");
	if (target > MaxClients) {
		DispatchSpawn(target);
		
		char buffer[128];
		FormatEx(buffer, sizeof(buffer), "classname %s", classname);
		SetVariantString(buffer);
		AcceptEntityInput(target, "AddOutput");
	}
	
	return target;
}

stock void MakeShake(float pos[3], float amplitude, float radius, float duration, float frequency) {
	int shake = CreateEntityByName("env_shake");
	if (shake != -1) {
		DispatchKeyValueVector(shake, "origin", pos);
		DispatchKeyValueFloat(shake, "amplitude", amplitude);
		DispatchKeyValueFloat(shake, "radius", radius * 2);
		DispatchKeyValueFloat(shake, "duration", duration);
		DispatchKeyValueFloat(shake, "frequency", frequency);
		
		SetVariantString("spawnflags 4"); // no physics (physics is 8), affects people in air (4)
		AcceptEntityInput(shake, "AddOutput");
		
		DispatchSpawn(shake);
		AcceptEntityInput(shake, "StartShake");
		RemoveEntity(shake);
	}
}

stock void SetViewmodelAnimation(int client, const char[] activity) {
	char buffer[PLATFORM_MAX_PATH];
	Format(buffer, sizeof(buffer), "local sequenceId = self.LookupSequence(`%s`);if (sequenceId != self.GetSequence()) self.SetSequence(sequenceId)", activity);
	SetVariantString(buffer);
	AcceptEntityInput(GetEntPropEnt(client, Prop_Send, "m_hViewModel"), "RunScriptCode");
}

stock void GetVectorAnglesTwoPoints(const float startPos[3], const float endPos[3], float angles[3]) {
	float tmpVec[3];
	tmpVec[0] = endPos[0] - startPos[0];
	tmpVec[1] = endPos[1] - startPos[1];
	tmpVec[2] = endPos[2] - startPos[2];
	GetVectorAngles(tmpVec, angles);
}

stock float RemapValClamped(float val, float a, float b, float c, float d) {
	if ( a == b )
		return val >= b ? d : c;
	
	float cVal = (val - a) / (b - a);
	cVal = clamp(cVal, 0.0, 1.0);
	
	return c + (d - c) * cVal;
}

stock float clamp(float val, float minVal, float maxVal) {
	if (maxVal < minVal)
		return maxVal;
	else if (val < minVal)
		return minVal;
	else if (val > maxVal)
		return maxVal;
	else
		return val;
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

public bool TraceRay_DontHitSelf(int entity, int mask, any data) {
	return (entity != data);
}