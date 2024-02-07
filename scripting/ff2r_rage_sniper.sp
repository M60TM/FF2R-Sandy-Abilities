/*
	"rage_make_explosion"
	{
		"stop_moving"	"true"
		"delay"			"0.1"	// I recommend to add delay. Because it can cause native error. 
		"particle"		"fluidSmokeExpl_ring_mvm"
		"radius"		"300.0"
		"damage"		"450.0"
		
		"plugin_name"	"ff2r_rage_sniper"
	}
	
	"special_rage_on_miss"
	{
		"rage"				"7.0"
		"range_multiplier"	"3.0"
		
		"plugin_name"	"ff2r_rage_sniper"
	}
	
	"sound_miss"
	{
		"misc/null.wav"	""
	}
*/

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2attributes>
#include <dhooks_gameconf_shim>
#include <cfgmap>
#include <ff2r>
#include <tf2utils>

#include <tf_damageinfo_tools>
#include <stocksoup/tf/tempents_stocks>

#pragma semicolon 1
#pragma newdecls required

Handle SDKCall_FindEntityInSphere;
Handle SDKCall_GetCombatCharacterPtr;

MoveType LastMoveType[MAXPLAYERS + 1];
ArrayList BossTimers[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[FF2R] Rage Sniper",
	author = "Sandy",
	description = "Full of R A G E",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	GameData data = new GameData("ff2r.sandy");
	if (!data) {
		SetFailState("Failed to load gamedata (ff2r.sandy).");
	} else if (!ReadDHooksDefinitions("ff2r.sandy")) {
		SetFailState("Failed to read gamedata (ff2r.sandy).");
	}
	
	StartPrepSDKCall(SDKCall_EntityList);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature,
			"CGlobalEntityList::FindEntityInSphere");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer,
			VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	SDKCall_FindEntityInSphere = EndPrepSDKCall();

	if (!SDKCall_FindEntityInSphere) {
		SetFailState("Failed to setup SDKCall for CGlobalEntityList::FindEntityInSphere");
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(data, SDKConf_Virtual,
			"CBaseEntity::MyCombatCharacterPointer");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	SDKCall_GetCombatCharacterPtr = EndPrepSDKCall();

	if (!SDKCall_GetCombatCharacterPtr) {
		SetFailState("Failed to setup SDKCall for CBaseEntity::MyCombatCharacterPointer");
	}
	
	DynamicDetour dynDetour_DoSwingTraceInternal = GetDHooksDetourDefinition(data, "CTFWeaponBaseMelee::DoSwingTraceInternal");
	dynDetour_DoSwingTraceInternal.Enable(Hook_Post, DynDetour_DoSwingTraceInternalPost);
	
	ClearDHooksDefinitions();
	delete data;
	
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			BossData boss = FF2R_GetBossData(client);
			if (boss) {
				FF2R_OnBossCreated(client, boss, false);
			}
		}
	}
}

public void FF2R_OnBossCreated(int client, BossData boss, bool setup) {
	if (!BossTimers[client]) {
		BossTimers[client] = new ArrayList();
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
	if (!StrContains(ability, "rage_make_explosion", false)) {
		if (cfg.GetBool("stop_moving", true)) {
			LastMoveType[client] = GetEntityMoveType(client);
			SetEntityMoveType(client, MOVETYPE_NONE);
		}
		
		DataPack pack;
		BossTimers[client].Push(CreateDataTimer(cfg.GetFloat("delay", 0.1), Timer_RageExplosion, pack));
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(ability);
	}
}

public Action Timer_RageExplosion(Handle timer, DataPack pack) {
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
		float pos[3];
		GetClientAbsOrigin(client, pos);
		
		char particle[64];
		cfg.GetString("particle", particle, sizeof(particle), "fluidSmokeExpl_ring_mvm");
		
		TE_SetupTFExplosion(pos, .weaponid = TF_WEAPON_GRENADELAUNCHER, .entity = client,
			.particleIndex = FindParticleSystemIndex(particle));
		TE_SendToAll();
		
		float radius = cfg.GetFloat("radius", 300.0);
		float damage = cfg.GetFloat("damage", 450.0);
		
		if (radius > 0.0 && damage > 0.0) {
			CTakeDamageInfo damageInfo = new CTakeDamageInfo(client, client, damage, DMG_BLAST | DMG_SLOWBURN, -1, _, pos, _);
			CTFRadiusDamageInfo radiusInfo = new CTFRadiusDamageInfo(damageInfo, pos, radius, client);
			
			radiusInfo.Apply();
			
			delete radiusInfo;
			delete damageInfo;
		}
		
		if (GetEntityMoveType(client) == MOVETYPE_NONE)
			SetEntityMoveType(client, LastMoveType[client]);
	}
	
	return Plugin_Continue;
}

MRESReturn DynDetour_DoSwingTraceInternalPost(int weapon, DHookReturn ret, DHookParam params) {
	// We have to check potential enemy for clean miss or not.
	if (!ret.Value) {
		RequestFrame(NextFrame_DoSwingTraceInternal, weapon);
	}
	
	return MRES_Ignored;
}

void NextFrame_DoSwingTraceInternal(int weapon) {
	if (!IsValidEntity(weapon)) {
		return;
	}
	
	int client = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client)) {
		return;
	}
	
	BossData boss = FF2R_GetBossData(client);
	if (!boss) {
		return;
	}
	
	AbilityData ability = boss.GetAbility("special_rage_on_miss");
	if (!ability.IsMyPlugin()) {
		return;
	}
	
	float pos[3];
	TF2Util_GetPlayerShootPosition(client, pos);
	
	float range = ability.GetFloat("range_multiplier", 3.0) * GetMeleeRange(client, weapon);
	
	bool notCleanMiss;
	int entity = -1;
	while ((entity = FindEntityInSphere(entity, pos, range)) != -1) {
		if (entity != client && IsEntityCombatCharacter(entity)) {
			notCleanMiss = true;
			break;
		}
	}
	
	if (notCleanMiss) {
		FF2R_EmitBossSoundToAll("sound_miss", client, _, client);
		boss.SetCharge(0, Min(ability.GetFloat("rage") + boss.GetCharge(0), boss.RageMax));
	}
}

static int FindEntityInSphere(int startEntity, const float pos[3], float radius) {
	return SDKCall(SDKCall_FindEntityInSphere, startEntity, pos, radius, Address_Null);
}

bool IsEntityCombatCharacter(int entity) {
	return SDKCall(SDKCall_GetCombatCharacterPtr, entity) != Address_Null;
}

int FindParticleSystemIndex(const char[] name) {
	int particleTable, particleIndex;
	if ((particleTable = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE) {
		ThrowError("Could not find string table: ParticleEffectNames");
	}
	if ((particleIndex = FindStringIndex(particleTable, name)) == INVALID_STRING_INDEX) {
		ThrowError("Could not find particle index: %s", name);
	}
	return particleIndex;
}

stock float GetMeleeRange(int client, int weapon) {
	float result;
	if (TF2_IsPlayerInCondition(client, TFCond_Charging)) {
		result = 128.0;
	} else {
		result = TF2Attrib_HookValueInt(0, "is_a_sword", weapon) > 0 ? 72.0 : 48.0;
	}
	
	result *= Max(1.0, GetEntPropFloat(client, Prop_Send, "m_flModelScale"));
	
	result *= TF2Attrib_HookValueFloat(1.0, "melee_range_multiplier", weapon);
	return result;
}

stock any Min(any a, any b) {
	return a > b ? b : a;
}

stock any Max(any a, any b) {
	return a > b ? a : b;
}