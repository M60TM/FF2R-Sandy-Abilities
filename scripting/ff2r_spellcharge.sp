/*
	"special_spell_charge"
	{
		"type"		"6"		// Spell type. 4 - Blast Jump, 6 - Teleport
		"height"	"0.78"	// Hud height.
		"delay"		"5.0"	// Initial cooldown
		"max"		"2"		// Max spell charge amount
		"cooldown"	"7.5"	// Cooldown
		"deploy"	"1.0"	// Deploy speed
		
		"plugin_name"	"ff2r_spellcharge"
	}
	
	"rage_spell_charge"
	{
		"type"		"0"		// Spell type. 1 - Fireball.
		"amount"	"2"		// Spell charge amount.
		
		"plugin_name"	"ff2r_spellcharge"
	}
*/
#include <sourcemod>
#include <tf2items>
#include <tf2utils>
#include <cfgmap>
#include <ff2r>

#pragma semicolon 1
#pragma newdecls required

#include "freak_fortress_2/subplugin.sp"

enum TFSpellType {
	Spell_FireBall = 0,
	Spell_BatSwarm,
	Spell_HealingAura,
	Spell_PumpkinBomb,
	Spell_BlastJump,
	Spell_Invisibility,
	Spell_Teleport,
	Spell_Lightning,
	Spell_Minify,
	Spell_MeteorShower,
	Spell_Monoculus,
	Spell_Skeleton = 11
};

Handle SyncHud;
bool SpellCharge[MAXPLAYERS + 1];
bool SpellRage[MAXPLAYERS + 1];
float SpellHUDHeight[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[FF2R] Spell Charge",
	author = "B14CK04K",
	description = "Gives passive to boss that can have chargeable halloween spell.",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart() {
	LoadTranslations("ff2r_spellcharge.phrases");
	
	SyncHud = CreateHudSynchronizer();
	
	HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);
	
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
	for(int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && FF2R_GetBossData(client)) {
			FF2R_OnBossRemoved(client);
		}
	}
}

public void OnMapStart() {
	PrecacheScriptSound("TFPlayer.ReCharged");
}

public void OnLibraryAdded(const char[] name) {
	Subplugin_LibraryAdded(name);
}

public void OnLibraryRemoved(const char[] name) {
	Subplugin_LibraryRemoved(name);
}

void OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
	if (GameRules_GetProp("m_bIsUsingSpells"))
		GameRules_SetProp("m_bIsUsingSpells", false);
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg) {
	if (!StrContains(ability, "rage_spell_charge", false)) {
		SpellRage[client] = true;
		
		int amount = cfg.GetInt("amount", 1);
		TFSpellType spellType = view_as<TFSpellType>(cfg.GetInt("type", Spell_FireBall));
		TF2_SetPlayerSpellType(client, spellType);
		TF2_SetPlayerSpellCharges(client, amount);
	}
}

public void FF2R_OnBossCreated(int client, BossData cfg, bool setup) {
	if (!setup || FF2R_GetGamemodeType() != 2) {
		if (!SpellCharge[client]) {
			AbilityData ability = cfg.GetAbility("special_spell_charge");
			if (ability.IsMyPlugin()) {
				SpellCharge[client] = true;
				ability.SetFloat("delay", GetGameTime() + ability.GetFloat("delay", 5.0));
				SpellHUDHeight[client] = ability.GetFloat("height", 0.73);
				
				if (!GameRules_GetProp("m_bIsUsingSpells"))
					GameRules_SetProp("m_bIsUsingSpells", true);
			}
		}
	}
}

public void FF2R_OnBossEquipped(int client, bool weapons) {
	if (weapons) {
		AbilityData ability = FF2R_GetBossData(client).GetAbility("special_spell_charge");
		if (ability.IsMyPlugin()) {
			int spellbook = TF2Util_GetPlayerLoadoutEntity(client, 9);
			if (IsValidEntity(spellbook)) {
				if (!HasEntProp(spellbook, Prop_Send, "m_iSpellCharges")) {
					TF2_RemoveWearable(client, spellbook);
					GiveSpellbook(client, ability.GetFloat("deploy", 1.0));
				}
			}
			else {
				GiveSpellbook(client, ability.GetFloat("deploy", 1.0));
			}
		}
	}
}

public void FF2R_OnBossRemoved(int client) {
	SpellCharge[client] = false;
	SpellRage[client] = false;
}

public void OnPlayerRunCmdPost(int client, int buttons) {
	if (SpellCharge[client]) {
		BossData boss = FF2R_GetBossData(client);
		AbilityData ability;
		if (boss && (ability = boss.GetAbility("special_spell_charge"))) {
			SpellCharge_Think(client, ability);
		}
		else {
			SpellCharge[client] = false;
		}
	}
}

void SpellCharge_Think(int client, ConfigData cfg) {
	if (!IsPlayerAlive(client)) {
		return;
	}
	
	float gameTime = GetGameTime();
	bool cooldown = cfg.GetBool("incooldown", true);
	float timeIn = cfg.GetFloat("delay");
	bool hud;
	
	int charge = TF2_GetPlayerSpellCharges(client);
	int max = cfg.GetInt("max", 1);
	
	if (SpellRage[client]) {
		if (charge < 1) {
			SpellRage[client] = false;
			cooldown = true;
			timeIn = gameTime + cfg.GetFloat("cooldown", 8.0);
			
			cfg.SetBool("incooldown", cooldown);
			cfg.SetFloat("delay", timeIn);
			
			hud = true;
		}
	}
	else if (max > charge) {
		if (cooldown) {
			if (timeIn < gameTime) {
				int amount = cfg.GetInt("amount", 1);
				if (max > charge + amount) {
					timeIn = gameTime + cfg.GetFloat("cooldown", 8.0);
					cfg.SetFloat("delay", timeIn);
				} else {
					cooldown = false;
					cfg.SetBool("incooldown", cooldown);
				}
				
				TFSpellType spellType = view_as<TFSpellType>(cfg.GetInt("type", Spell_FireBall));
				TF2_SetPlayerSpellType(client, spellType);
				TF2_SetPlayerSpellCharges(client, Min(max, charge + amount));
				EmitGameSoundToClient(client, "TFPlayer.ReCharged");
				
				hud = true;
			}
		}
		else {
			cooldown = true;
			timeIn = gameTime + cfg.GetFloat("cooldown", 8.0);
			
			cfg.SetBool("incooldown", cooldown);
			cfg.SetFloat("delay", timeIn);
			
			hud = true;
		}
	}
	
	if ((hud || cfg.GetFloat("hudin") < gameTime) && GameRules_GetRoundState() != RoundState_TeamWin) {
		cfg.SetFloat("hudin", gameTime + 0.09);
		SetGlobalTransTarget(client);
		if (SpellRage[client]) {
			SetHudTextParams(-1.0, SpellHUDHeight[client], 0.1, 255, 255, 255, 255);
			ShowSyncHudText(client, SyncHud, "%t", "Rage Spell Charge");
		}
		else if (cooldown) {
			float time = timeIn - gameTime + 0.09;
			if (time < 999.9) {
				SetHudTextParams(-1.0, SpellHUDHeight[client], 0.1, 255, 255, 255, 255);
				ShowSyncHudText(client, SyncHud, "%t", "Spell Charge Cooltime", time);
			}
		}
		else {
			SetHudTextParams(-1.0, SpellHUDHeight[client], 0.1, 255, 255, 255, 255);
			ShowSyncHudText(client, SyncHud, "%t", "Full Spell Charge");
		}
	}
}

stock int TF2_GetPlayerSpellBook(int client) {
	int spellbook = TF2Util_GetPlayerLoadoutEntity(client, 9);
	if (IsValidEntity(spellbook) && HasEntProp(spellbook, Prop_Send, "m_iSpellCharges")) {
		return spellbook;
	}
	
	return -1;
}

stock bool TF2_SetPlayerSpellType(int client, TFSpellType spell) {
	int spellbook = TF2_GetPlayerSpellBook(client);
	if (IsValidEntity(spellbook)) {
		SetEntProp(spellbook, Prop_Send, "m_iSelectedSpellIndex", spell);
		return true;
	}
	return false;
}

stock int TF2_GetPlayerSpellCharges(int client) {
	int spellbook = TF2_GetPlayerSpellBook(client);
	if (IsValidEntity(spellbook)) {
		return GetEntProp(spellbook, Prop_Send, "m_iSpellCharges");
	}
	return 0;
}

stock int TF2_SetPlayerSpellCharges(int client, int count) {
	int spellbook = TF2_GetPlayerSpellBook(client);
	if (IsValidEntity(spellbook)) {
		SetEntProp(spellbook, Prop_Send, "m_iSpellCharges", count);
		return true;
	}
	return false;
}

stock void GiveSpellbook(int client, float flMultDeploySpeed = 1.0) {
	Handle weaponHandle = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);
	TF2Items_SetClassname(weaponHandle, "tf_weapon_spellbook");
	TF2Items_SetItemIndex(weaponHandle, 1069);
	TF2Items_SetLevel(weaponHandle, 0);
	TF2Items_SetQuality(weaponHandle, 0);
		
	TF2Items_SetNumAttributes(weaponHandle, 2);
	TF2Items_SetAttribute(weaponHandle, 0, 547, flMultDeploySpeed);
	//TF2Items_SetAttribute(weaponHandle, 0, 138, 0.33);
	TF2Items_SetAttribute(weaponHandle, 1, 15, 0.0);
	
	int spellbook = TF2Items_GiveNamedItem(client, weaponHandle);
	delete weaponHandle;
	
	if (spellbook > -1) {
		EquipPlayerWeapon(client, spellbook);
		SetEntityRenderMode(spellbook, RENDER_ENVIRONMENTAL);
	}
}

stock any Min(any a, any b) {
	return a > b ? b : a;
}