#include <sourcemod>
#include <cfgmap>
#include <ff2r>
#include <tf_custom_attributes>

public Plugin myinfo = {
	name = "[FF2R] Airblast cause Rage",
	author = "B14CK04K",
	description = "For bypassing negative assist",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	HookEvent("object_deflected", Events_ObjectDeflected, EventHookMode_Post);
}

Action Events_ObjectDeflected(Event event, const char[] name, bool dontBroadcast) {
	if (!event.GetInt("weaponid")) {	// TF_WEAPON_NONE
		int victim = GetClientOfUserId(event.GetInt("ownerid"));
		if (!IsPlayerAlive(victim)) {
			return Plugin_Continue;
		}
		
		BossData boss = FF2R_GetBossData(victim);
		if (boss) {
			int attacker = GetClientOfUserId(event.GetInt("userid"));
			if (!attacker) {
				return Plugin_Continue;
			}
			
			int weapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
			if (weapon == -1) {
				return Plugin_Continue;
			}
			
			float amount = TF2CustAttr_GetFloat(weapon, "airblast cause rage");
			if (amount != 0.0) {
				float rage = boss.GetCharge(0);
				float maxrage = boss.RageMax;
				if (rage < maxrage) {
					rage += amount;
					if (rage > maxrage) {
						FF2R_EmitBossSoundToAll("sound_full_rage", attacker, _, attacker, SNDCHAN_AUTO, SNDLEVEL_AIRCRAFT, _, 2.0);
						rage = maxrage;
					}
					else if (rage < 0.0) {
						rage = 0.0;
					}
					
					boss.SetCharge(0, rage);
				}
			}
		}
	}
	return Plugin_Continue;
}