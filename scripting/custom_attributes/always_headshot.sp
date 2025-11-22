#include <sourcemod>
#include <dhooks>
#include <sdkhooks>
#include <tf_econ_dynamic>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

DynamicHook DHookCanFireCriticalShot;
DynamicHook DHookGetDamageType;

public Plugin myinfo = {
	name = "[TF2] Always Headshot",
	author = "B14CK04K",
	description = "Bypassing distance and accuracy limit on ambassador headshot",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	GameData gamedata = new GameData("tf2.sandy");
	if (gamedata == null) {
		SetFailState("Failed to load gamedata (tf2.sandy)");
	}
	
	DHookCanFireCriticalShot = DynamicHook.FromConf(gamedata, "CTFWeaponBase::CanFireCriticalShot");
	DHookGetDamageType = DynamicHook.FromConf(gamedata, "CTFWeaponBase::GetDamageType");
	
	delete gamedata;

	TF2EconDynAttribute attrib = new TF2EconDynAttribute();
	attrib.SetCustom("hidden", "1");
	
	attrib.SetName("independent headshot in accuracy");
	attrib.SetClass("independent_headshot_in_accuracy");
	attrib.SetCustom("stored_as_integer", "1");
	attrib.SetDescriptionFormat("value_is_additive");
	attrib.Register();
	
	attrib.SetName("independent headshot in distance");
	attrib.SetClass("independent_headshot_in_distance");
	attrib.Register();
	
	delete attrib;
	
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "tf_weapon_revolver")) != -1) {
		HookWeaponEntity(entity);
	}
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (!StrContains(classname, "tf_weapon_revolver")) {
		HookWeaponEntity(entity);
	}
}

void HookWeaponEntity(int revolver) {
	DHookCanFireCriticalShot.HookEntity(Hook_Post, revolver, DHook_CanFireCriticalShot);
	DHookGetDamageType.HookEntity(Hook_Post, revolver, DHook_RevolverDamageType);
}

MRESReturn DHook_CanFireCriticalShot(int weapon, DHookReturn ret, DHookParam params) {
	if (ret.Value) {
		return MRES_Ignored;
	}
	
	// Bypass 1200HU limit in revolver.
	if (TF2Attrib_HookValueInt(0, "independent_headshot_in_distance", weapon)) {
		ret.Value = params.Get(1);
		return MRES_Override;
	}
	
	return MRES_Ignored;
}

MRESReturn DHook_RevolverDamageType(int revolver, DHookReturn ret) {
	if (TF2Attrib_HookValueInt(0, "independent_headshot_in_accuracy", revolver)) {
		ret.Value = ret.Value | DMG_USE_HITLOCATIONS;
		return MRES_Override;
	}
	
	return MRES_Ignored;
}