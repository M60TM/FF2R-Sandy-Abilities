#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <tf2attributes>
#include <ff2r>
#include <tf_damageinfo_tools>

#pragma newdecls required

#define SHREDALERT_EXPLOSION_DELAY 3.1

enum {
	TK_HADOUKEN = 0,
	TK_HIGH_NOON,
	TK_GRAND_SLAM,
	TK_FENCING,
	TK_ARROW_STAB,
	TK_GRENADE = 5,
	TK_BARBARIAN_SWING,
	TK_UBERSLICE,
	TK_ENGINEER_SMASH,
	TK_ENGINEER_ARM,
	TK_ARMAGEDDON = 10,
	TK_FLARE_PELLET,
	TK_ALLCLASS_GUITAR_RIFF,
	TK_GASBLAST,
	TK_MAXCOUNT = 14
};

Handle AnnounceHud;

ConVar g_CvarTauntKillDamageMulti[TK_MAXCOUNT];
ConVar g_CvarAllowShredAlertTauntKill;
ConVar g_CvarShredAlertTauntDamage;
ConVar g_CvarShredAlertTauntRadius;
ConVar g_CvarMaxTauntKillDamage;

public Plugin myinfo = {
	name = "[FF2R] Taunt Kill Modifications",
	author = "Original by Ankhxy, Changed and Ported by Sandy",
	description = "Adds various functionality around taunt kills",
	version = "1.0.0"
}

public void OnPluginStart() {
	g_CvarTauntKillDamageMulti[TK_HADOUKEN] = CreateConVar("ff2_hadouken_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_HIGH_NOON] = CreateConVar("ff2_high_noon_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_GRAND_SLAM] = CreateConVar("ff2_grand_slam_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_FENCING] = CreateConVar("ff2_fencing_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_ARROW_STAB] = CreateConVar("ff2_arrow_stab_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_GRENADE] = CreateConVar("ff2_grenade_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_BARBARIAN_SWING] = CreateConVar("ff2_barbarian_swing_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_UBERSLICE] = CreateConVar("ff2_uberslice_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_ENGINEER_SMASH] = CreateConVar("ff2_engineer_smash_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_ENGINEER_ARM] = CreateConVar("ff2_engineer_arm_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_ARMAGEDDON] = CreateConVar("ff2_armageddon_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_FLARE_PELLET] = CreateConVar("ff2_flare_pellet_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_ALLCLASS_GUITAR_RIFF] = CreateConVar("ff2_shredalert_damage_mult", "1.0", "", 0, true, 0.0);
	g_CvarTauntKillDamageMulti[TK_GASBLAST] = CreateConVar("ff2_gasblast_damage_mult", "1.0", "", 0, true, 0.0);

	g_CvarAllowShredAlertTauntKill = CreateConVar("ff2_allow_shredalert_taunt_kill", "1", "allow to 1, block to 0", 0, true, 0.0, true, 1.0);
	g_CvarShredAlertTauntDamage = CreateConVar("ff2_shredalert_taunt_damage", "500.0", "shred alert explosion damage", 0, true, 0.0);
	g_CvarShredAlertTauntRadius = CreateConVar("ff2_shredalert_taunt_radius", "175.0", "shred alert explosion radius", 0, true, 0.0);
	g_CvarMaxTauntKillDamage = CreateConVar("ff2_tauntkill_maxdamage", "10000.0", "taunt kill max damage", 0, true, 0.0);

	AnnounceHud = CreateHudSynchronizer();

	// Late Load.
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
}

Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
	if (!IsValidClient(attacker) || !IsValidClient(victim))
		return Plugin_Continue;
	
	if (!FF2R_GetBossData(victim))
		return Plugin_Continue;
	
	float damagemult = 1.0;
	bool announce = false;
	
	switch(damagecustom) {
		case TF_CUSTOM_TAUNT_HADOUKEN: {
			damagemult = g_CvarTauntKillDamageMulti[TK_HADOUKEN].FloatValue;
			announce = true;
		}
		case TF_CUSTOM_TAUNT_HIGH_NOON: {
			damagemult = g_CvarTauntKillDamageMulti[TK_HIGH_NOON].FloatValue;
			announce = true;
		}
		case TF_CUSTOM_TAUNT_GRAND_SLAM: {
			damagemult = g_CvarTauntKillDamageMulti[TK_GRAND_SLAM].FloatValue;
			announce = true;
		}
		case TF_CUSTOM_TAUNT_FENCING: {
			if (damage > 75.0) {
				damagemult = g_CvarTauntKillDamageMulti[TK_FENCING].FloatValue;
				announce = true;
			}
		}
		case TF_CUSTOM_TAUNT_ARROW_STAB: {
			if (damage > 75.0) {
				damagemult = g_CvarTauntKillDamageMulti[TK_ARROW_STAB].FloatValue;
				announce = true;
			}
		}
		case TF_CUSTOM_TAUNT_GRENADE: {
			damagemult = g_CvarTauntKillDamageMulti[TK_GRENADE].FloatValue;
			announce = true;
		}
		case TF_CUSTOM_TAUNT_BARBARIAN_SWING: {
			damagemult = g_CvarTauntKillDamageMulti[TK_BARBARIAN_SWING].FloatValue;
			announce = true;
		}
		case TF_CUSTOM_TAUNT_UBERSLICE: {
			if (damage > 75.0) {
				damagemult = g_CvarTauntKillDamageMulti[TK_UBERSLICE].FloatValue;
				announce = true;
			}
		}
		case TF_CUSTOM_TAUNT_ENGINEER_SMASH: {
			damagemult = g_CvarTauntKillDamageMulti[TK_ENGINEER_SMASH].FloatValue;
			announce = true;
		}
		case TF_CUSTOM_TAUNT_ENGINEER_ARM: {
			if (damage > 75.0) {
				damagemult = g_CvarTauntKillDamageMulti[TK_ENGINEER_ARM].FloatValue;
				announce = true;
			}
		}
		case TF_CUSTOM_TAUNT_ARMAGEDDON: {
			damagemult = g_CvarTauntKillDamageMulti[TK_ARMAGEDDON].FloatValue;
			announce = true;
		}
		case TF_CUSTOM_FLARE_PELLET: {
			if (TF2_IsPlayerInCondition(attacker, TFCond_Taunting)) {
				damagemult = g_CvarTauntKillDamageMulti[TK_FLARE_PELLET].FloatValue;
				announce = true;
			}
		}
		case TF_CUSTOM_TAUNT_ALLCLASS_GUITAR_RIFF: {
			damagemult = g_CvarTauntKillDamageMulti[TK_ALLCLASS_GUITAR_RIFF].FloatValue;
			announce = true;
		}
		case TF_CUSTOM_TAUNTATK_GASBLAST: {
			damagemult = g_CvarTauntKillDamageMulti[TK_GASBLAST].FloatValue;
			announce = true;
		}
	}

	if (announce) {
		damage *= damagemult;
			
		if (damage > g_CvarMaxTauntKillDamage.FloatValue) {
			damage = g_CvarMaxTauntKillDamage.FloatValue;
		}
			
		if (damage < 0.0) {
			damage = 0.0;
		}

		AnnounceTauntKill(attacker, victim, damage);

		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

void AnnounceTauntKill(int attacker, int boss, float damage) {
	SetHudTextParams(-1.0, 0.2, 5.0, 255, 255, 255, 255);
		
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			if (client == boss)
				ShowSyncHudText(client, AnnounceHud, "%N got a taunt kill against you for %1.0f damage!", attacker, damage);
			else if (client == attacker)
				ShowSyncHudText(client, AnnounceHud, "You got a taunt kill against %N for %1.0f damage!", boss, damage);
			else
				ShowSyncHudText(client, AnnounceHud, "%N got a taunt kill against %N for %1.0f damage!", attacker, boss, damage);
		}
	}
}

public void TF2_OnConditionAdded(int client, TFCond cond) {
	if (g_CvarAllowShredAlertTauntKill.BoolValue) {
		if (cond == TFCond_Taunting) {
			if (GetEntProp(client, Prop_Send, "m_iTauntItemDefIndex") == 1015) { // Shred Alert.
				float delay = SHREDALERT_EXPLOSION_DELAY / TF2Attrib_HookValueFloat(1.0, "mult_gesture_time", client);
				CreateTimer(delay, Timer_ShredAlertTauntKill, client, TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
}

Action Timer_ShredAlertTauntKill(Handle timer, int client) {
	if (!IsValidClient(client))
		return Plugin_Continue;
	
	if (TF2_IsPlayerInCondition(client, TFCond_Taunting) && GetEntProp(client, Prop_Send, "m_iTauntItemDefIndex") == 1015) {
		float pos[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);

		CTakeDamageInfo damageInfo = new CTakeDamageInfo(client, client, g_CvarShredAlertTauntDamage.FloatValue, DMG_BLAST | DMG_USEDISTANCEMOD | DMG_HALF_FALLOFF, -1, pos, pos, pos, TF_CUSTOM_TAUNT_ALLCLASS_GUITAR_RIFF);

		CTFRadiusDamageInfo radiusInfo = new CTFRadiusDamageInfo(damageInfo, pos, g_CvarShredAlertTauntRadius.FloatValue, client);

		radiusInfo.Apply();
		
		delete radiusInfo;
		delete damageInfo;
	}

	return Plugin_Continue;
}

stock bool IsValidClient(int client, bool replaycheck=true) {
	if (client<=0 || client>MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
		return false;

	if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
		return false;

	return true;
}