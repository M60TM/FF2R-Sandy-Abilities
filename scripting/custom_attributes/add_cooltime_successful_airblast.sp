#include <sourcemod>
#include <dhooks>
#include <tf2attributes>
#include <tf_custom_attributes>
#include <tf2utils>

#pragma semicolon 1
#pragma newdecls required

DynamicHook DHookSecondaryAttack;

public Plugin myinfo = {
	name = "[TF2] Add Cooltime on Successful Airblast",
	author = "B14CK04K",
	description = "",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	GameData gamedata = new GameData("tf2.cattr_airblastjump");
	if (gamedata == null) {
		SetFailState("Failed to load gamedata (tf2.cattr_airblastjump)");
	}

	DynamicDetour detourFireAirBlast = DynamicDetour.FromConf(gamedata, "CTFFlameThrower::FireAirBlast()");
	detourFireAirBlast.Enable(Hook_Post, Detour_FireAirBlastPost);
	
	delete gamedata;
	
	gamedata = new GameData("tf2.cattr_starterpack");
	if (gamedata == null) {
		SetFailState("Failed to load gamedata (tf2.cattr_starterpack)");
	}

	DHookSecondaryAttack = DynamicHook.FromConf(gamedata, "CBaseCombatWeapon::SecondaryAttack()");
	
	delete gamedata;
	
	HookEvent("object_deflected", Events_ObjectDeflected, EventHookMode_Post);
	
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "tf_weapon_rocketlauncher_fireball")) != -1) {
		HookWeaponEntity(entity);
	}
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (StrEqual(classname, "tf_weapon_rocketlauncher_fireball")) {
		HookWeaponEntity(entity);
		
	}
}

static void HookWeaponEntity(int weapon) {
	DHookEntity(DHookSecondaryAttack, true, weapon, _, DHook_SecondaryAttackPost);
}

static bool s_SuccessfulDeflect;
public Action Events_ObjectDeflected(Event event, const char[] name, bool dontBroadcast) {
	if (!event.GetInt("weaponid")) {
		int victim = GetClientOfUserId(event.GetInt("ownerid"));
		if (victim > 0 && victim <= MaxClients && IsPlayerAlive(victim)) {
			int attacker = GetClientOfUserId(event.GetInt("userid"));
			if (attacker) {
				int weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
				if (weapon != -1) {
					if (TF2Util_GetWeaponID(weapon) == TF_WEAPON_FLAME_BALL) {
						float scale = TF2CustAttr_GetFloat(weapon, "rescale on successful airblast");
						if (scale > 0.0) {
							s_SuccessfulDeflect = true;
						}
					} else {
						float cooltime = TF2CustAttr_GetFloat(weapon, "add cooltime successful airblast");
						if (cooltime) {
							s_SuccessfulDeflect = true;
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

MRESReturn Detour_FireAirBlastPost(int weapon, DHookParam params) {
	float cooltime = TF2CustAttr_GetFloat(weapon, "add cooltime successful airblast");
	if (cooltime && s_SuccessfulDeflect && TF2Util_GetWeaponID(weapon) != TF_WEAPON_FLAME_BALL) {
		s_SuccessfulDeflect = false;
		
		float gameTime = GetGameTime();
		SetEntPropFloat(weapon, Prop_Data, "m_flNextPrimaryAttack", gameTime + TF2Attrib_HookValueFloat(cooltime, "mult_airblast_primary_refire_time", weapon));
		SetEntPropFloat(weapon, Prop_Data, "m_flNextSecondaryAttack", gameTime + cooltime);
	}
	
	return MRES_Ignored;
}

MRESReturn DHook_SecondaryAttackPost(int weapon) {
	float scale = TF2CustAttr_GetFloat(weapon, "rescale on successful airblast");
	if (scale > 0.0 && s_SuccessfulDeflect) {
		s_SuccessfulDeflect = false;
		
		//PrintToChatAll("%.1f", scale);
		SetEntPropFloat(weapon, Prop_Send, "m_flRechargeScale", scale);
	}
	
	return MRES_Ignored;
}