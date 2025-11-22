#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#include <tf_custom_attributes>
#include <tf_ontakedamage>

public Plugin myinfo = {
	name = "[TF2] Mod Crit-type while Wrangled",
	author = "B14CK04K",
	description = "",
	version = "1.0.0",
	url = ""
};

public Action TF2_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage,
		int &damagetype, int &weapon, float damageForce[3], float damagePosition[3],
		int damagecustom, CritType &critType) {
	if (victim < 1 || victim > MaxClients || attacker < 1 || attacker > MaxClients) {
		return Plugin_Continue;
	}
	
	if (inflictor > MaxClients && IsValidEntity(inflictor)) {
		char classname[64];
		GetEntityClassname(inflictor, classname, sizeof(classname));
		if (!StrContains(classname, "obj_sentrygun") && GetEntProp(inflictor, Prop_Send, "m_bPlayerControlled")) {
			int wrangler = GetPlayerWeaponSlot(attacker, TFWeaponSlot_Secondary);
			if (!IsValidEntity(wrangler)) {
				return Plugin_Continue;
			}
			
			// set to 1 for mini-crits, 2 for full crits
			CritType modifiedCritType = view_as<CritType>(TF2CustAttr_GetInt(wrangler, "sentry crit type while wrangled"));
			if (modifiedCritType <= critType) {
				return Plugin_Continue;
			}
			
			critType = modifiedCritType;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}