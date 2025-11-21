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
	
	"special_block_suicide"
	{
		"plugin_name"	"ff2r_standard_trait"
	}
*/
#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <cfgmap>
#include <ff2r>
#include <tf2utils>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

#define DEFINDEX_UNDEFINED 65535

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

int PlayersAlive[4];
bool SpecTeam;

bool SpecialDisguise[MAXPLAYERS + 1];
float DisguiseDamage[MAXPLAYERS + 1];

//int SpecialAutoRage[MAXPLAYERS + 1];
//float SpecialAutoRageTime[MAXPLAYERS + 1];

bool NoActive[MAXPLAYERS + 1] = { false, ... };
bool BlockDropRune[MAXPLAYERS + 1];
bool BlockSuicide[MAXPLAYERS + 1];

ArrayList BlockSuicideBoss;
ArrayList BossTimers[MAXPLAYERS + 1];

Handle PlayerOverlayTimer[MAXPLAYERS + 1] = { null, ... };

ConVar mp_friendlyfire;
ConVar ff2_block_suicide;

#include "freak_fortress_2/formula_parser.sp"
#include "freak_fortress_2/subplugin.sp"
//#include "ff2r_standard_trait/dhooks.sp"
#include "ff2r_standard_trait/events.sp"
#include "ff2r_standard_trait/sdktools.sp"

public void OnPluginStart() {
	ff2_block_suicide = CreateConVar("ff2_block_suicide", "0", "Block suicide", 0, true, 0.0, true, 1.0);
	
	SDKCall_Setup();
	
	
	mp_friendlyfire = FindConVar("mp_friendlyfire");
	
	Events_OnPluginStart();
	
	BlockSuicideBoss = new ArrayList();
	
	AddCommandListener(Command_DropItem, "dropitem");
	AddCommandListener(Command_KermitSewerSlide, "explode");
	AddCommandListener(Command_KermitSewerSlide, "kill");
	AddCommandListener(Command_Spectate, "spectate");
	AddCommandListener(Command_JoinTeam, "jointeam");
	
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

public void OnMapStart() {
	PrecacheEffect("ParticleEffectStop");
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
				if (DisguiseDamage[client] < 0.0)
					DisguiseDamage[client] = 0.0;
					
				DisguiseDamage[client] += ability.GetFloat("damage", 300.0);
			}
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

Action Command_KermitSewerSlide(int client, const char[] command, int args) {
	if (ff2_block_suicide.BoolValue && GameRules_GetRoundState() != RoundState_TeamWin)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

Action Command_Spectate(int client, const char[] command, int args) {
	if (ff2_block_suicide.BoolValue && GameRules_GetRoundState() != RoundState_TeamWin)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

Action Command_JoinTeam(int client, const char[] command, int args) {
	char buffer[10];
	GetCmdArg(1, buffer, sizeof(buffer));
	if (StrEqual(buffer, "spectate", false) && ff2_block_suicide.BoolValue && GameRules_GetRoundState() != RoundState_TeamWin) {
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (StrEqual(classname, "item_powerup_rune"))
		AcceptEntityInput(entity, "Kill");
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if(0 < attacker <= MaxClients && IsClientInGame(attacker) && GetClientTeam(victim) != GetClientTeam(attacker))
	{
		if(SpecialDisguise[victim])
		{
			BossData boss = FF2R_GetBossData(victim);
			if (boss && boss.GetAbility("special_disguise")) {
				DisguiseDamage[victim] -= damage;
				if (DisguiseDamage[victim] <= 0.0)
					TF2_RemoveCondition(victim, TFCond_Disguised);
				
				return;
			}
			
			SpecialDisguise[victim] = false;
		}
		
		SDKUnhook(victim, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	}
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
				SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
			}
		}
		
		if (!BlockSuicide[client]) {
			ability = cfg.GetAbility("special_block_suicide");
			if (ability.IsMyPlugin()) {
				BlockSuicide[client] = true;
				if (!BlockSuicideBoss.Length)
					ff2_block_suicide.BoolValue = true;
				
				BlockSuicideBoss.Push(client);
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
		
		ability = boss.GetAbility("special_boss_particle");
		if (ability.IsMyPlugin()) {
			ApplyBossParticle(client, ability);
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
	
	BlockDropRune[client] = false;
	SpecialDisguise[client] = false;
	
	if (BlockSuicide[client]) {
		int index = BlockSuicideBoss.FindValue(client);
		if (index != -1) {
			BlockSuicideBoss.Erase(index);
			if (!BlockSuicideBoss.Length)
				ff2_block_suicide.BoolValue = false;
		}
		
		BlockSuicide[client] = false;
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

void Rage_SelfHeal(int client, ConfigData cfg) {
	int amount = 0;
	if (cfg.GetBool("amount", false)) {
		amount = RoundFloat(GetFormula(cfg, "gain", TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : GetClientTeam(client)), 0.0));
	}
	else {
		amount = RoundFloat(SDKCall_GetClientMaxHealth(client) * GetFormula(cfg, "percentage", TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : GetClientTeam(client)), 0.0));
	}
	
	if (amount > 0) {
		int health = Min(GetClientHealth(client) + amount, SDKCall_GetClientMaxHealth(client));
		SetEntityHealth(client, health);
		
		Event event = CreateEvent("player_healonhit", true);
	
		event.SetInt("entindex", client);
		event.SetInt("amount", amount);
		
		event.Fire();
	}
}

bool ApplyHealOnKill(int client, int victim, ConfigData cfg) {
	if (cfg.GetBool("milk") && !TF2_IsPlayerInCondition(victim, TFCond_Milked)) {
		return false;
	}
	
	int amount = 0;
	switch (cfg.GetInt("type")) {
		case 1: {
			amount = RoundFloat(GetFormula(cfg, "gain", TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : GetClientTeam(client)), 0.0));
		}
		case 2: {
			amount = RoundFloat(SDKCall_GetClientMaxHealth(client) * cfg.GetFloat("percentage"));
		}
		default: {
			amount = RoundFloat(SDKCall_GetClientMaxHealth(victim) * cfg.GetFloat("multiplier", 1.0));
		}
	}
	
	if (amount > 0) {
		int health = Min(GetClientHealth(client) + amount, SDKCall_GetClientMaxHealth(client));
		SetEntityHealth(client, health);
		
		Event event = CreateEvent("player_healonhit", true);
	
		event.SetInt("entindex", client);
		event.SetInt("amount", amount);
		
		event.Fire();
	}
	
	return true;
}

Action Timer_RageBossAttribute(Handle timer, DataPack pack) {
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());

	if (!client)
		return Plugin_Handled;
	
	BossTimers[client].Erase(BossTimers[client].FindValue(timer));
	
	char buffer[64];
	pack.ReadString(buffer, sizeof(buffer));
	
	BossData boss = FF2R_GetBossData(client);
	AbilityData cfg = boss.GetAbility(buffer);
	if (cfg.IsMyPlugin()) {
		if (cfg.GetBool("reset", false))
			SDKCall_RemoveAllCustomAttribute(client);
		
		ApplyBossAttributes(client, cfg);
	}
	
	return Plugin_Continue;
}

void ApplyBossAttributes(int client, ConfigData cfg) {
	ConfigData cfgAttribute = cfg.GetSection("attributes");
	StringMapSnapshot snap = cfgAttribute.Snapshot();
	
	PackVal attributeValue;
	
	int team = GetClientTeam(client);
	int alive = TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : team);
	
	int entries = snap.Length;
	char buffer[2][64];
	for (int i; i < entries; i++) {
		int length = snap.KeyBufferSize(i) + 1;
		char[] key = new char[length];
		snap.GetKey(i, key, length);
		
		if (cfgAttribute.GetArray(key, attributeValue, sizeof(attributeValue))) {
			switch (attributeValue.tag) {
				case KeyValType_Value: {
					ExplodeString(attributeValue.data, ";", buffer, sizeof(buffer), sizeof(buffer[]));
					float value = ParseFormula(buffer[0], alive);
					float duration = ParseFormula(buffer[1], alive);
					TF2Attrib_AddCustomPlayerAttribute(client, key, value, duration);
				}
				case KeyValType_Section: {
					float value = GetFormula(view_as<ConfigData>(attributeValue.cfg), "value", alive);
					float duration = GetFormula(view_as<ConfigData>(attributeValue.cfg), "duration", alive);
					TF2Attrib_AddCustomPlayerAttribute(client, key, value, duration);
				}
			}
		}
	}
	
	delete snap;
}

void ApplyBossParticle(int client, ConfigData cfg) {
	ConfigData cfgParticle = cfg.GetSection("particles");
	StringMapSnapshot snap = cfgParticle.Snapshot();
	
	int entries = snap.Length;
	if (entries > 0) {
		char model[PLATFORM_MAX_PATH];
		GetClientModel(client, model, sizeof(model));
		
		int prop = CreateEntityByName("tf_taunt_prop");
		DispatchSpawn(prop);
		ActivateEntity(prop);
		SetEntityModel(prop, model);
		
		SetEntityRenderColor(prop, 0, 0, 0, 0);
		SetEntityRenderMode(prop, RENDER_TRANSALPHA);

		SetEntProp(prop, Prop_Send, "m_fEffects", GetEntProp(prop, Prop_Send, "m_fEffects")|EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW);
		SetEntPropEnt(prop, Prop_Data, "m_hEffectEntity", client);

		SetVariantString("!activator");
		AcceptEntityInput(prop, "SetParent", client);
		
		for (int i; i < entries; i++) {
			int length = snap.KeyBufferSize(i) + 1;
			char[] key = new char[length];
			snap.GetKey(i, key, length);
			
			ConfigData val = cfgParticle.GetSection(key);
			if (val) {
				char particle[64];
				if (!val.GetString("particle", particle, sizeof(particle)))
					continue;
				
				ParticleAttachment_t attachtype = view_as<ParticleAttachment_t>(val.GetInt("attachment_type", 6));
				
				char point[64];
				if (val.GetString("attachment_point", point, sizeof(point))) {
					int attachpoint = LookupEntityAttachment(client, point);
					if (attachpoint) {
						TE_SetupTFParticleEffect(particle, NULL_VECTOR, _, _, prop, attachtype, attachpoint, false);
						TE_SendToAll(0.0);
					}
				}
				else {
					TE_SetupTFParticleEffect(particle, NULL_VECTOR, _, _, prop, attachtype, -1, false);
					TE_SendToAll(0.0);
				}
			}
		}
		
		SetEdictFlags(prop, GetEdictFlags(prop) | FL_EDICT_ALWAYS);
		CreateTimer(0.2, Timer_ApplySetTransmit, prop, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	delete snap;
}

/*
void ApplyBossParticle(int client, ConfigData cfg) {
	ConfigData cfgParticle = cfg.GetSection("particles");
	StringMapSnapshot snap = cfgParticle.Snapshot();
	
	int entries = snap.Length;
	for (int i; i < entries; i++) {
		int length = snap.KeyBufferSize(i) + 1;
		char[] key = new char[length];
		snap.GetKey(i, key, length);
		
		ConfigData val = cfgParticle.GetSection(key);
		if (val) {
			char particle[64];
			if (!val.GetString("particle", particle, sizeof(particle)))
				continue;
			
			//PrintToChatAll("%s", particle);
			
			int entity = TF2_AttachParticle(particle, client);
			SetEdictFlags(entity, GetEdictFlags(entity) | FL_EDICT_ALWAYS);
			CreateTimer(0.2, Timer_ApplySetTransmit, entity, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	delete snap;
}
*/

void ClearBossParticle(int client) {
	/*
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "info_particle_system")) != INVALID_ENT_REFERENCE) {
		if (GetEntPropEnt(entity, Prop_Data, "m_pParent") != client)
			continue;
		
		SetVariantString("ParticleEffectStop");
		AcceptEntityInput(entity, "DispatchEffect");
		AcceptEntityInput(entity, "ClearParent");
		
		// Some particles don't get removed properly, teleport far away then delete it
		static const float outsidePos[3] = {8192.0, 8192.0, 8192.0};
		TeleportEntity(entity, outsidePos);
		
		// Give enough time for effect to fade out before getting destroyed
		SetVariantString("OnUser1 !self:Kill::0.5:1");
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");
	}
	*/
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "tf_taunt_prop")) != INVALID_ENT_REFERENCE) {
		if (GetEntPropEnt(entity, Prop_Data, "m_hParent") == client) {
			SetVariantString("ParticleEffectStop");
			AcceptEntityInput(entity, "DispatchEffect");
			AcceptEntityInput(entity, "ClearParent");
			
			static const float outsidePos[3] = {8192.0, 8192.0, 8192.0};
			TeleportEntity(entity, outsidePos);
			
			SetVariantString("OnUser1 !self:Kill::0.5:1");
			AcceptEntityInput(entity, "AddOutput");
			AcceptEntityInput(entity, "FireUser1");
		}
	}
}

Action Timer_ApplySetTransmit(Handle timer, int entity) {
	// Entity reference here
	if (IsValidEntity(entity)) {
		SetEdictFlags(entity, GetEdictFlags(entity) & ~FL_EDICT_ALWAYS);
		SDKHook(entity, SDKHook_SetTransmit, AttachEnt_SetTransmit);
	}
	
	return Plugin_Continue;
}

Action AttachEnt_SetTransmit(int attachEnt, int client) {
	int owner = GetEntPropEnt(attachEnt, Prop_Data, "m_pParent");
	if (owner == INVALID_ENT_REFERENCE)
		return Plugin_Stop;
	
	if (owner != client) {
		if (GetEntPropEnt(client, Prop_Send, "m_hObserverTarget") == owner && GetEntProp(client, Prop_Send, "m_iObserverMode") == OBS_MODE_IN_EYE)
		    return Plugin_Stop;
	}
	else if (!TF2_IsPlayerInCondition(owner, TFCond_Taunting) && !GetEntProp(owner, Prop_Send, "m_nForceTauntCam")) {
		return Plugin_Stop;
	}

	if (TF2_IsPlayerInCondition(owner, TFCond_Cloaked) || TF2_IsPlayerInCondition(owner, TFCond_Disguised) || TF2_IsPlayerInCondition(owner, TFCond_Stealthed))
		return Plugin_Stop;
	
	return Plugin_Continue;
}

public Action Timer_RemovePlayerOverlay(Handle timer, int userid) {
	int client = GetClientOfUserId(userid);
	
	if (client) {
		PlayerOverlayTimer[client] = null;
		SetVariantString("");
		AcceptEntityInput(client, "SetScriptOverlayMaterial", client, client);
	}
	return Plugin_Continue;
}

float GetFormula(ConfigData cfg, const char[] key, int players, float defaul = 0.0) {
	static char buffer[1024];
	if (!cfg.GetString(key, buffer, sizeof(buffer)))
		return defaul;
	
	return ParseFormula(buffer, players);
}

float GetBossCharge(ConfigData cfg, const char[] slot, float defaul = 0.0) {
	int length = strlen(slot)+7;
	char[] buffer = new char[length];
	Format(buffer, length, "charge%s", slot);
	return cfg.GetFloat(buffer, defaul);
}

void SetBossCharge(ConfigData cfg, const char[] slot, float amount) {
	int length = strlen(slot)+7;
	char[] buffer = new char[length];
	Format(buffer, length, "charge%s", slot);
	cfg.SetFloat(buffer, amount);
}

int TotalPlayersAliveEnemy(int team = -1) {
	int amount;
	for (int i = SpecTeam ? 0 : 2; i < sizeof(PlayersAlive); i++) {
		if (i != team)
			amount += PlayersAlive[i];
	}
	
	return amount;
}

stock void PrecacheEffect(const char[] sEffectName) {
	static int table = INVALID_STRING_TABLE;
	if (table == INVALID_STRING_TABLE) {
		table = FindStringTable("EffectDispatch");
	}
	
	bool save = LockStringTables(false);
	AddToStringTable(table, sEffectName);
	LockStringTables(save);
}

/*
stock int TF2_AttachParticle(const char[] particle, int client) {
	char model[PLATFORM_MAX_PATH];
	GetClientModel(client, model, sizeof(model));
	
	int prop = CreateEntityByName("tf_taunt_prop");
	DispatchSpawn(prop);
	ActivateEntity(prop);
	SetEntityModel(prop, model);
	
	SetEntityRenderColor(prop, 0, 0, 0, 0);
	SetEntityRenderMode(prop, RENDER_TRANSALPHA);

	SetEntProp(prop, Prop_Send, "m_fEffects", GetEntProp(prop, Prop_Send, "m_fEffects")|EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW);
	SetEntPropEnt(prop, Prop_Data, "m_hEffectEntity", client);

	SetVariantString("!activator");
	AcceptEntityInput(prop, "SetParent", client);
	
	TE_SetupTFParticleEffect(particle, NULL_VECTOR, _, _, prop, PATTACH_ROOTBONE_FOLLOW, -1, false);
	TE_SendToAll(0.0);
	
	//Return ref of entity
	return EntIndexToEntRef(prop);
}
*/

stock any Min(any a, any b) {
	return a > b ? b : a;
}