#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

static DynamicHook DHookShouldTransmit;
static DynamicHook DHookUpdateTransmitState;

void DHook_Setup() {
	GameData gamedata = new GameData("ff2r.sandy");
	if (!gamedata)
		SetFailState("Failed to load gamedata (ff2r.sandy).");
	
	DHookShouldTransmit = DynamicHook.FromConf(gamedata, "CBaseEntity::ShouldTransmit");
	if (!DHookShouldTransmit)
		LogError("[Gamedata] Could not find CBaseEntity::ShouldTransmit");
	
	DHookUpdateTransmitState = DynamicHook.FromConf(gamedata, "CBaseEntity::UpdateTransmitState");
	if (!DHookUpdateTransmitState)
		LogError("[Gamedata] Could not find CBaseEntity::UpdateTransmitState");
	
	delete gamedata;
}

void DHook_AlwaysTransmitEntity(int entity) {
	if (DHookShouldTransmit)
		DHookShouldTransmit.HookEntity(Hook_Pre, entity, DHook_ShouldTransmit);
	if (DHookUpdateTransmitState)
		DHookUpdateTransmitState.HookEntity(Hook_Pre, entity, DHook_UpdateTransmitState);
}

static MRESReturn DHook_ShouldTransmit(int entity, DHookReturn ret, DHookParam params) {
	ret.Value = FL_EDICT_ALWAYS;
	return MRES_Supercede;
}

static MRESReturn DHook_UpdateTransmitState(int entity, DHookReturn returnHook) {
	returnHook.Value = SetEntityTransmitState(entity, FL_EDICT_FULLCHECK, true);
	return MRES_Supercede;
}