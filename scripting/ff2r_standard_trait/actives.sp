#pragma semicolon 1
#pragma newdecls required

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