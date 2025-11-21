#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

static DynamicHook DHookShouldTransmit;

void DHook_Setup() {
	GameData gamedata = new GameData("ff2r.sandy");
	if (!gamedata)
		SetFailState("Failed to load gamedata (ff2r.sandy).");
	
	DHookShouldTransmit = DynamicHook.FromConf(gamedata, "CBaseEntity::ShouldTransmit");
	if (!DHookShouldTransmit)
		LogError("[Gamedata] Could not find CBaseEntity::ShouldTransmit");
	
	delete gamedata;
}

void DHook_AlwaysTransmitEntity(int entity) {
	if (DHookShouldTransmit)
		DHookShouldTransmit.HookEntity(Hook_Post, entity, DHook_ShouldTransmit);
}

MRESReturn DHook_ShouldTransmit(int entity, DHookReturn ret, DHookParam params) {
	ret.Value = FL_EDICT_ALWAYS;
	return MRES_Supercede;
}