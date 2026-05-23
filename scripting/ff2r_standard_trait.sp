/*
	"special_kill_log"
	{
		"weaponid"
		{
			"8" // It must be a number corresponding to TF_WEAPON_* in tf2_stocks.inc 
			{
				"name"	"fists"
			}
			"tf_projectile_rocket"	// Or kill icon name in mod_textures.txt
			{
				"name"	"fists"
			}
		}
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"special_kill_overlay"
	{
		"duration"	"3.25"
		"path"		""
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"special_rage_on_kill"
	{
		"slot"		"0"
		"amount"	"10.0"
		"subtract"	"false"
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"special_heal_on_kill"
	{
		"milk"			"false"
		"type"			"0"
		"multiplier"	"2.0"
		"gain"			"300.0 + n"
		"percentage"	"0.05"
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"passive_blockdropitem"
	{
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"special_boss_attribute"
	{
		"attributes"
		{
			"dmg from ranged reduced"		"0.8 ; -1.0"	// 205
			"damage force reduction"		"0.4 ; -1.0"	// 252
			"cannot pick up intelligence"	"1.0 ; -1.0"	// 400
		}
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"special_boss_particle"
	{
		"particles"
		{
			"1"
			{
				"particle"	"ghost_pumpkin"
			}
		}
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"rage_special_theme"
	{
		"slot"		"0"
		"required"	""
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"sound_special_theme"
	{
		"neon_inferno/ff2/painiscupcake/rage.mp3"
		{
			"key"	""
			"time"	"16"
		}
	}
	
	"rage_boss_attribute"
	{
		"slot"		"0"
		"attributes"
		{
			"melee attack rate bonus"			"0.6 ; 7.0"
		}
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"rage_boss_attribute"
	{
		"slot"		"0"
		"attributes"
		{
			"melee attack rate bonus"
			{
				"value"		"0.7"
				"duration"	"7.0 + (n / 10)"
			}
		}
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"rage_bad_effect"
	{
		"slot"				"0"
		"jarate"			"true"
		"milk"				"true"
		"stun"				"true"
		"bleed"				"true"
		"marked_for_death"	"true"
		"sapper"			"true"
		"taunt"				"true"
		"stop_motion"		"false"
		
		"plugin_name"	"ff2r_standard_trait"
	}
	
	"special_outline_on_destroy"
	{
		"builder_only"		"false"
		"duration"			"4.0"
		"radius"			"700.0"
		"show_builder"		"true"
		
		"plugin_name"	"ff2r_standard_trait"
	}
*/
#include <sourcemod>
#include <dhooks>
#include <sdkhooks>
#include <tf2_stocks>
#include <cfgmap>
#include <ff2r>
#include <tf2utils>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

// #include <stocksoup/tf/econ>
#include <stocksoup/tf/tempents_stocks>

enum {
	EF_BONEMERGE			= (1<<0),	// Performs bone merge on client side
	EF_BRIGHTLIGHT			= (1<<1),	// DLIGHT centered at entity origin
	EF_DIMLIGHT				= (1<<2),	// player flashlight
	EF_NOINTERP				= (1<<3),	// don't interpolate the next frame
	EF_NOSHADOW				= (1<<4),	// Don't cast no shadow
	EF_NODRAW				= (1<<5),	// don't draw entity
	EF_NORECEIVESHADOW		= (1<<6),	// Don't receive no shadow
	EF_BONEMERGE_FASTCULL	= (1<<7),	// For use with EF_BONEMERGE. If this is set, then it places this ent's origin at its
										// parent and uses the parent's bbox + the max extents of the aiment.
										// Otherwise, it sets up the parent's bones every frame to figure out where to place
										// the aiment, which is inefficient because it'll setup the parent's bones even if
										// the parent is not in the PVS.
	EF_ITEM_BLINK			= (1<<8),	// blink an item so that the user notices it.
	EF_PARENT_ANIMATES		= (1<<9),	// always assume that the parent entity is animating
};

enum {
	OBS_MODE_NONE = 0,	// not in spectator mode
	OBS_MODE_DEATHCAM,	// special mode for death cam animation
	OBS_MODE_FREEZECAM,	// zooms to a target, and freeze-frames on them
	OBS_MODE_FIXED,		// view from a fixed camera position
	OBS_MODE_IN_EYE,	// follow a player in first person view
	OBS_MODE_CHASE,		// follow a player in third person view
	OBS_MODE_POI,		// PASSTIME point of interest - game objective, big fight, anything interesting; added in the middle of the enum due to tons of hard-coded "<ROAMING" enum compares
	OBS_MODE_ROAMING,	// free roaming

	NUM_OBSERVER_MODES,
};

native void FF2_SetClientGlow(int client, float add, float set=-1.0);

int PlayersAlive[4];
bool SpecTeam;

bool SpecialDisguise[MAXPLAYERS + 1];
int DisguiseDamage[MAXPLAYERS + 1];

//int SpecialAutoRage[MAXPLAYERS + 1];
//float SpecialAutoRageTime[MAXPLAYERS + 1];

bool NoActive[MAXPLAYERS + 1] = { false, ... };
bool BlockDropRune[MAXPLAYERS + 1];
bool HealOnKill[MAXPLAYERS + 1];

ArrayList HealOnKillList;
ArrayList BossTimers[MAXPLAYERS + 1];

Handle PlayerOverlayTimer[MAXPLAYERS + 1] = { null, ... };

bool SpecialParticle[MAXPLAYERS + 1];

ConVar mp_friendlyfire;

#include "freak_fortress_2/formula_parser.sp"
#include "freak_fortress_2/subplugin.sp"
#include "ff2r_standard_trait/stocks.sp"
#include "ff2r_standard_trait/events.sp"
#include "ff2r_standard_trait/dhooks.sp"
#include "ff2r_standard_trait/sdktools.sp"
#include "ff2r_standard_trait/miscs.sp"
#include "ff2r_standard_trait/actives.sp"
#include "ff2r_standard_trait/passives.sp"

public Plugin myinfo = {
	name = "[FF2R] Standard Trait",
	author = "B14CK04K",
	description = "Provides passive and active abilities.",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	DHook_Setup();
	SDKCall_Setup();
	
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	
	Events_OnPluginStart();
	
	HealOnKillList = new ArrayList();
	
	AddCommandListener(Command_DropItem, "dropitem");
	
	Subplugin_PluginStart();
}

void FF2R_PluginLoaded() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			BossData cfg = FF2R_GetBossData(client);
			if (cfg) {
				FF2R_OnBossCreated(client, cfg, false);
				FF2R_OnBossEquipped(client, true);
			}
		}
	}
}

public void OnPluginEnd() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client)) {
			if (PlayerOverlayTimer[client])
				TriggerTimer(PlayerOverlayTimer[client]);
			
			if (FF2R_GetBossData(client))
				FF2R_OnBossRemoved(client);
		}
	}
}

public void OnMapStart() {
	PrecacheEffect("ParticleEffectStop");
}

public void OnMapEnd() {
	HealOnKillList.Clear();
}

public void OnLibraryAdded(const char[] name) {
	Subplugin_LibraryAdded(name);
}

public void OnLibraryRemoved(const char[] name) {
	Subplugin_LibraryRemoved(name);
}

public void OnClientDisconnect(int client) {
	delete PlayerOverlayTimer[client];
}

public void TF2_OnConditionAdded(int client, TFCond condition) {
	if (condition == TFCond_Disguised) {
		if (SpecialDisguise[client]) {
			BossData boss = FF2R_GetBossData(client);
			AbilityData ability = boss.GetAbility("special_disguise");
			if (ability.IsMyPlugin()) {
				DisguiseDamage[client] = ability.GetInt("damage", 300);
			}
		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition) {
	if (condition == TFCond_Disguised) {
		if (SpecialDisguise[client]) {
			DisguiseDamage[client] = 0;
		}
	}
}

Action Command_DropItem(int client, const char[] command, int argc) {
	if (IsClientInGame(client)) {
		if (BlockDropRune[client]) {
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (StrEqual(classname, "item_powerup_rune"))
		AcceptEntityInput(entity, "Kill");
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!BossTimers[client]) {
		BossTimers[client] = new ArrayList();
	}
	
	if (!BlockDropRune[client]) {
		AbilityData ability = cfg.GetAbility("special_blockdropitem");
		if (ability.IsMyPlugin()) {
			BlockDropRune[client] = true;
		}
		else {
			ability = cfg.GetAbility("passive_blockdropitem");
			if (ability.IsMyPlugin())
				BlockDropRune[client] = true;
		}
	}
	
	if(!setup || FF2R_GetGamemodeType() != 2) {
		AbilityData ability;
		if (!SpecialDisguise[client]) {
			ability = cfg.GetAbility("special_disguise");
			if (ability.IsMyPlugin()) {
				SpecialDisguise[client] = true;
			}
		}
		
		if (!HealOnKill[client]) {
			ability = cfg.GetAbility("special_heal_on_kill");
			if (ability.IsMyPlugin()) {
				HealOnKill[client] = true;
				HealOnKillList.Push(client);
			}
		}
		/*
		if (!SpecialAutoRage[client]) {
			ability = cfg.GetAbility("special_generate_rage");
			if (ability.IsMyPlugin()) {
				SpecialAutoRage[client] = 1;
				SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
			}
		}
		*/
	}
}

public void FF2R_OnBossEquipped(int client, bool weapons) {
	if (weapons) {
		BossData boss = FF2R_GetBossData(client);
		AbilityData ability = boss.GetAbility("special_boss_attribute");
		if (ability.IsMyPlugin()) {
			ApplyBossAttributes(client, ability);
		}
		
		if (!SpecialParticle[client]) {
			ability = boss.GetAbility("special_boss_particle");
			if (ability.IsMyPlugin()) {
				ApplyBossParticle(client, ability);
			}
		}
	}
}

public void FF2R_OnBossRemoved(int client) {
	int length = BossTimers[client].Length;
	for (int i; i < length; i++) {
		Handle timer = BossTimers[client].Get(i);
		delete timer;
	}
	delete BossTimers[client];
	
	NoActive[client] = false;
	BlockDropRune[client] = false;
	SpecialDisguise[client] = false;
	
	if (HealOnKill[client]) {
		int index = HealOnKillList.FindValue(client);
		if (index != -1) {
			HealOnKillList.Erase(index);
		}
		
		HealOnKill[client] = false;
	}
	
	ClearBossParticle(client);
	
	// If you death, game should be call this function. But you changed boss, custom attribute is still remaining.
	// So here is fix for that.
	if (IsPlayerAlive(client)) {
		SDKCall_RemoveAllCustomAttribute(client);
	}
}

public Action FF2R_OnAbilityPre(int client, const char[] ability, AbilityData cfg, bool &result) {
	return NoActive[client] ? Plugin_Stop : Plugin_Continue;
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "rage_special_theme")) {
		char required[8];
		cfg.GetString("required", required, sizeof(required));
		FF2R_EmitBossSoundToAll("sound_special_theme", client, required);
	}
	else if (!StrContains(ability, "rage_boss_attribute", false)) {
		DataPack pack;
		BossTimers[client].Push(CreateDataTimer(GetFormula(cfg, "delay", TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : GetClientTeam(client))), Timer_RageBossAttribute, pack));
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(ability);
	}
	else if (!StrContains(ability, "rage_bad_effect", false)) {
		if (cfg.GetBool("jarate", true)) {
			TF2_RemoveCondition(client, TFCond_Jarated);
		}
		
		if (cfg.GetBool("milk", true)) {
			TF2_RemoveCondition(client, TFCond_Milked);
		}
		
		if (cfg.GetBool("stun", true)) {
			TF2_RemoveCondition(client, TFCond_Dazed);
		}
		
		if (cfg.GetBool("bleed", true)) {
			TF2_RemoveCondition(client, TFCond_Bleeding);
		}
		
		if (cfg.GetBool("marked_for_death", true)) {
			TF2_RemoveCondition(client, TFCond_MarkedForDeath);
		}
		
		if (cfg.GetBool("sapper", true)) {
			TF2_RemoveCondition(client, TFCond_Dazed);
			TF2_RemoveCondition(client, TFCond_Sapped);
		}
		
		if (cfg.GetBool("taunt", true)) {
			TF2_RemoveCondition(client, TFCond_Taunting);
			if (cfg.GetBool("stop_motion", false)) {
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, {0.0, 0.0, 200.0});
			}
		}
	}
	else if (!StrContains(ability, "rage_give_ammo", false)) {
		int ammotype = cfg.GetInt("ammotype", 1);
		if (ammotype >= 0) {
			int ammo = RoundFloat(GetFormula(cfg, "ammo", TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : GetClientTeam(client))));
			int max = RoundFloat(GetFormula(cfg, "max", TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : GetClientTeam(client))));
			if (max >= 0 && ammo > max) {
				ammo = max;
			}
			
			if (ammo > 0) {
				SetEntProp(client, Prop_Data, "m_iAmmo", ammo, _, ammotype);
			}
		}
	}
	else if (!StrContains(ability, "rage_give_clip", false)) {
		int slot = cfg.GetInt("loadout", 0);
		int weapon = GetPlayerWeaponSlot(client, slot);
		if (IsValidEntity(weapon)) {
			int clip = 0;
			if (cfg.GetBool("percent", false)) {
				float flPercent = GetFormula(cfg, "clip", TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : GetClientTeam(client)), 1.0);
				clip = RoundFloat(float(TF2Util_GetWeaponMaxClip(weapon)) * flPercent); 
			}
			else {
				clip = RoundFloat(GetFormula(cfg, "clip", TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : GetClientTeam(client))));
			}
			
			if (clip >= 0)
				SetEntProp(weapon, Prop_Data, "m_iClip1", clip);
		}
	}
	else if (!StrContains(ability, "rage_self_heal", false)) {
		Rage_SelfHeal(client, cfg);
	}
}

public void FF2R_OnAliveChanged(const int alive[4], const int total[4]) {
	for (int i; i < 4; i++) {
		PlayersAlive[i] = alive[i];
	}
	
	SpecTeam = (total[TFTeam_Unassigned] || total[TFTeam_Spectator]);
}

public void FF2R_OnBossModifier(int client, ConfigData cfg) {
	BossData boss = FF2R_GetBossData(client);
	
	if (cfg.GetBool("noactive")) {
		NoActive[client] = true;
		
		if (boss.GetAbility("special_rage_on_kill").IsMyPlugin())
			boss.Remove("special_rage_on_kill");
	}
}
