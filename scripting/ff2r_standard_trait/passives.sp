#pragma semicolon 1
#pragma newdecls required

void Passive_PlayerHurt(int victim, int attacker, int damage) {
	BossData boss = FF2R_GetBossData(attacker);
	if (boss) {
		AbilityData ability = boss.GetAbility("special_rage_on_damage");
		if (ability.IsMyPlugin())
			ApplyRageOnDamage(attacker, boss, damage);
		
		if (SpecialDisguise[victim])
			ReduceDisguiseOnTakeDamage(victim, damage);
	}
}

void Passive_PlayerDeath(int victim, int attacker, int customkill, bool deadRinger) {
	if (attacker == victim || !attacker || customkill == TF_CUSTOM_SUICIDE || customkill == TF_CUSTOM_TRIGGER_HURT) {
		TryToApplyHealOnKillBosses(victim, deadRinger);
		return;
	}
	
	if (0 < attacker <= MaxClients) {
		BossData boss = FF2R_GetBossData(attacker);
		if (boss) {
			AbilityData ability = boss.GetAbility("special_kill_overlay");
			if (ability.IsMyPlugin())
				ApplyOverlayOnKill(victim, ability, deadRinger);
			
			ability = boss.GetAbility("special_rage_on_kill");
			if (ability.IsMyPlugin())
				ApplyRageOnKill(attacker, boss, ability, deadRinger);
			
			ability = boss.GetAbility("special_heal_on_kill");
			if (ability.IsMyPlugin() && ApplyHealOnKill(attacker, victim, ability, deadRinger))
				FF2R_UpdateBossAttributes(attacker);
			
			if (customkill == TF_CUSTOM_BACKSTAB) {
				ability = boss.GetAbility("special_disguise_on_backstab");
				if (ability.IsMyPlugin())
					ApplyDisguiseOnBackstab(attacker, victim);
			}
		}
	}
}

void Passive_ObjectDestroyed(int entity, int attacker) {
	if (!attacker)
		return;
	
	BossData boss = FF2R_GetBossData(attacker);
	if (boss) {
		AbilityData ability = boss.GetAbility("special_outline_on_destroy");
		if (ability.IsMyPlugin()) {
			ApplyOutlineOnDestroy(entity, attacker, ability);
		}
	}
}

static void ApplyRageOnDamage(int client, BossData boss, int damage) {
	float ragedmg = boss.RageDamage;
	if (ragedmg > 0.0) {
		float rage = boss.GetCharge(0);
		float maxrage = boss.RageMax;
		if (rage < maxrage) {
			rage += (damage * 100.0 / ragedmg);
			if (rage > maxrage) {
				FF2R_EmitBossSoundToAll("sound_full_rage", client, _, client, SNDCHAN_AUTO, SNDLEVEL_AIRCRAFT, _, 2.0);
				rage = maxrage;
			}
			
			boss.SetCharge(0, rage);
		}
	}
}

static void ReduceDisguiseOnTakeDamage(int client, int damage) {
	DisguiseDamage[client] -= damage;
	if (DisguiseDamage[client] <= 0) {
		TF2_RemovePlayerDisguise(client);
		DisguiseDamage[client] = 0;
	}
}

static void ApplyOverlayOnKill(int client, ConfigData cfg, bool deadRinger) {
	if (!cfg.GetBool("dead_ringer") || !deadRinger) {
		char file[128];
		cfg.GetString("path", file, sizeof(file));
		
		SetVariantString(file);
		AcceptEntityInput(client, "SetScriptOverlayMaterial", client, client);
		
		delete PlayerOverlayTimer[client];
		PlayerOverlayTimer[client] = CreateTimer(cfg.GetFloat("duration", 3.25), Timer_RemovePlayerOverlay, GetClientUserId(client));
	}
}

static void ApplyRageOnKill(int client, BossData boss, ConfigData cfg, bool deadRinger) {
	if (cfg.GetBool("dead_ringer") && deadRinger)
		return;
	
	if (boss.RageDamage > 0.0) {
		float amount = GetFormula(cfg, "amount", TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : GetClientTeam(client)), 0.0);
		
		char slot[8];
		cfg.GetString("slot", slot, sizeof(slot), "0");
		
		float rage = GetBossCharge(boss, slot);
		float maxrage = boss.RageMax;
		if (rage < maxrage) {
			rage += amount;
			if (rage > maxrage) {
				FF2R_EmitBossSoundToAll("sound_full_rage", client, _, client, SNDCHAN_AUTO, SNDLEVEL_AIRCRAFT, _, 2.0);
				rage = maxrage;
			}
			else if (rage < 0.0) {
				rage = 0.0;
			}
			
			SetBossCharge(boss, slot, rage);
		}
	}
}

static void TryToApplyHealOnKillBosses(int victim, bool deadRinger) {
	int length = HealOnKillList.Length;
	for (int i = 0; i < length; i++) {
		int client = HealOnKillList.Get(i);
		if (client == victim)
			continue;
		
		if (!IsPlayerAlive(client))
			continue;
		
		BossData boss = FF2R_GetBossData(client);
		AbilityData ability = boss.GetAbility("special_heal_on_kill");
		if (ability.IsMyPlugin()) {
			if (ApplyHealOnKill(client, victim, ability, deadRinger))
				FF2R_UpdateBossAttributes(client);
		}
	}
}

static bool ApplyHealOnKill(int client, int victim, ConfigData cfg, bool deadRinger) {
	if (cfg.GetBool("dead_ringer") && deadRinger)
		return false;
	
	if (cfg.GetBool("milk") && !TF2_IsPlayerInCondition(victim, TFCond_Milked))
		return false;
	
	int amount = 0;
	switch (cfg.GetInt("type")) {
		case 1: {
			amount = RoundFloat(GetFormula(cfg, "gain", TotalPlayersAliveEnemy(mp_friendlyfire.BoolValue ? -1 : GetClientTeam(client)), 0.0));
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

static void ApplyDisguiseOnBackstab(int client, int victim) {
	TFTeam team = TF2_GetClientTeam(victim);
	TFClassType classType = TF2_GetPlayerClass(victim);
	TF2_DisguisePlayer(client, team, classType, victim);
}

static void ApplyOutlineOnDestroy(int entity, int attacker, ConfigData cfg) {
	if (cfg.GetBool("builder_only", true)) {
		int builder = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
		if (0 < builder <= MaxClients && IsClientInGame(builder) && IsPlayerAlive(builder)) {
			float duration = cfg.GetFloat("duration", 4.0);
			FF2_SetClientGlow(builder, 0.0, duration);
		}
	}
	else {
		int team = GetEntProp(entity, Prop_Send, "m_iTeamNum");
		float duration = cfg.GetFloat("duration", 4.0);
		float radius = cfg.GetFloat("radius", 700.0);
		radius = radius * radius;
		
		bool showBuilder = cfg.GetBool("show_builder");
		int builder = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
		
		float pos[3], targetPos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		for (int target = 1; target <= MaxClients; target++) {
			if (target == attacker || !IsClientInGame(target) || !IsPlayerAlive(target))
				continue;
			
			if (showBuilder && target == builder)
				continue;
			
			if (GetClientTeam(target) != team)
				continue;
			
			GetEntPropVector(target, Prop_Send, "m_vecOrigin", targetPos);
			if (GetVectorDistance(pos, targetPos, true) > radius)
				continue;
			
			FF2_SetClientGlow(target, 0.0, duration);
		}
		
		if (showBuilder && (0 < builder <= MaxClients && IsClientInGame(builder) && IsPlayerAlive(builder))) {
			FF2_SetClientGlow(builder, 0.0, duration);
		}
	}
}