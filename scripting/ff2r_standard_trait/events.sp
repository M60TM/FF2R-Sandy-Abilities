#pragma semicolon 1
#pragma newdecls required

void Events_OnPluginStart() {
	HookEvent("player_death", OnPlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("object_destroyed", OnObjectDestroyed, EventHookMode_Pre);
}

static Action OnPlayerDeathPre(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker) {
		return Plugin_Continue;
	}
	
	BossData boss = FF2R_GetBossData(attacker);
	if (boss) {
		AbilityData ability = boss.GetAbility("special_kill_log");
		if (ability.IsMyPlugin()) {
			// first, check weapon id
			int weaponID = event.GetInt("weaponid");
			
			char buffer[64];
			Format(buffer, sizeof(buffer), "weaponid.%d", weaponID);
			ConfigData SectionID = ability.GetSection(buffer);
			if (SectionID) {
				SectionID.GetString("name", buffer, sizeof(buffer));
				event.SetString("weapon_logclassname", buffer);
				event.SetString("weapon", buffer);
				
				return Plugin_Changed;
			} 
			else { // If it doesn't exist, check weapon name
				event.GetString("weapon", buffer, sizeof(buffer));
				if (buffer[0]) {
					FormatEx(buffer, sizeof(buffer), "weaponid.%s", buffer);
					SectionID = ability.GetSection(buffer);
					if (SectionID) {
						SectionID.GetString("name", buffer, sizeof(buffer));
						event.SetString("weapon_logclassname", buffer);
						event.SetString("weapon", buffer);
						
						return Plugin_Changed;
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

static Action OnObjectDestroyed(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker) {
		return Plugin_Continue;
	}
	
	BossData boss = FF2R_GetBossData(attacker);
	if (boss) {
		AbilityData ability = boss.GetAbility("special_kill_log");
		if (ability.IsMyPlugin()) {
			// first, check weapon id
			int weaponID = event.GetInt("weaponid");
			
			char buffer[64];
			Format(buffer, sizeof(buffer), "weaponid.%d", weaponID);
			ConfigData SectionID = ability.GetSection(buffer);
			if (SectionID) {
				SectionID.GetString("name", buffer, sizeof(buffer));
				event.SetString("weapon_logclassname", buffer);
				event.SetString("weapon", buffer);
				
				return Plugin_Changed;
			} 
			else { // If it doesn't exist, check weapon name
				event.GetString("weapon", buffer, sizeof(buffer));
				if (buffer[0]) {
					FormatEx(buffer, sizeof(buffer), "weaponid.%s", buffer);
					SectionID = ability.GetSection(buffer);
					if (SectionID) {
						SectionID.GetString("name", buffer, sizeof(buffer));
						event.SetString("weapon_logclassname", buffer);
						event.SetString("weapon", buffer);
						
						return Plugin_Changed;
					}
				}
			}
		}
	}
	
	return Plugin_Continue;
}

static void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (victim) {
		if (attacker < 1 || attacker > MaxClients || attacker == victim) {
			return;
		}
		
		BossData boss = FF2R_GetBossData(attacker);
		if (boss) {
			AbilityData ability = boss.GetAbility("special_kill_overlay");
			if (ability.IsMyPlugin()) {
				if (!ability.GetBool("dead_ringer") || !(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER)) {
					char file[128];
					ability.GetString("path", file, sizeof(file));
					
					SetVariantString(file);
					AcceptEntityInput(victim, "SetScriptOverlayMaterial", victim, victim);
					
					delete PlayerOverlayTimer[victim];
					PlayerOverlayTimer[victim] = CreateTimer(ability.GetFloat("duration", 3.25), Timer_RemovePlayerOverlay, GetClientUserId(victim));
				}
			}
			
			ability = boss.GetAbility("special_rage_on_kill");
			if (ability.IsMyPlugin()) {
				if (boss.RageDamage > 0.0) {
					float amount = GetFormula(ability, "amount", TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : GetClientTeam(attacker)), 0.0);
					
					char slot[8];
					ability.GetString("slot", slot, sizeof(slot), "0");
					
					float rage = GetBossCharge(boss, slot);
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
						
						SetBossCharge(boss, slot, rage);
					}
				}
			}
			
			ability = boss.GetAbility("special_heal_on_kill");
			if (ability.IsMyPlugin() && ApplyHealOnKill(attacker, victim, ability)) {
				FF2R_UpdateBossAttributes(attacker);
			}
			
			if (event.GetInt("customkill") == TF_CUSTOM_BACKSTAB) {
				ability = boss.GetAbility("special_disguise_on_backstab");
				if (ability.IsMyPlugin()) {
					TFTeam team = TF2_GetClientTeam(victim);
					TFClassType classType = TF2_GetPlayerClass(victim);
					TF2_DisguisePlayer(attacker, team, classType, victim);
				}
			}
		}
	}
}