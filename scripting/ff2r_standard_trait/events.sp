#pragma semicolon 1
#pragma newdecls required

void Events_OnPluginStart() {
	HookEvent("player_hurt", Events_PlayerHurt, EventHookMode_Post);
	HookEvent("player_death", Events_PlayerDeathPre, EventHookMode_Pre);
	HookEvent("player_death", Events_PlayerDeath, EventHookMode_Post);
	HookEvent("object_destroyed", Events_ObjectDestroyedPre, EventHookMode_Pre);
	HookEvent("object_destroyed", Events_ObjectDestroyed, EventHookMode_Post);
}

static void Events_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (victim < 1 || victim > MaxClients)
		return;
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (victim == attacker || attacker < 1 || attacker > MaxClients)
		return;
	
	int damage = event.GetInt("damageamount");
	Passive_PlayerHurt(victim, attacker, damage);
}

static Action Events_PlayerDeathPre(Event event, const char[] name, bool dontBroadcast) {
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

static Action Events_ObjectDestroyedPre(Event event, const char[] name, bool dontBroadcast) {
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

static void Events_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (victim) {
		bool deadRinger = view_as<bool>(event.GetInt("death_flags") & TF_DEATHFLAG_DEADRINGER);
		int customkill = event.GetInt("customkill");
		Passive_PlayerDeath(victim, attacker, customkill, deadRinger);
	}
}

static void Events_ObjectDestroyed(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int entity = event.GetInt("index");
	if (IsValidEntity(entity)) {
		Passive_ObjectDestroyed(entity, attacker);
	}
}