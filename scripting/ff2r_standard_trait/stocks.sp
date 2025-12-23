#pragma semicolon 1
#pragma newdecls required

Action Timer_ApplySetTransmit(Handle timer, int ref) {
	// Entity reference here
	int entity = EntRefToEntIndex(ref);
	if (IsValidEntity(entity)) {
		SetEdictFlags(entity, GetEdictFlags(entity) & ~FL_EDICT_ALWAYS);
		SDKHook(entity, SDKHook_SetTransmit, AttachEnt_SetTransmit);
	}
	
	return Plugin_Continue;
}

static Action AttachEnt_SetTransmit(int attachEnt, int client) {
	int owner = GetEntPropEnt(attachEnt, Prop_Data, "m_hEffectEntity");
	if (owner < 1 || owner > MaxClients)
		return Plugin_Handled;
	
	if (owner == client) {
		if (!TF2_IsPlayerInCondition(owner, TFCond_Taunting) && !GetEntProp(owner, Prop_Send, "m_nForceTauntCam")) {
			return Plugin_Handled;
		}
	}
	else {
		if (GetEntPropEnt(client, Prop_Send, "m_hObserverTarget") == owner && GetEntProp(client, Prop_Send, "m_iObserverMode") == OBS_MODE_IN_EYE)
			return Plugin_Handled;
	}
	
	if (TF2_IsPlayerInCondition(owner, TFCond_Cloaked) || TF2_IsPlayerInCondition(owner, TFCond_Disguised) || TF2_IsPlayerInCondition(owner, TFCond_Stealthed))
		return Plugin_Handled;
	
	return Plugin_Continue;
}

Action Timer_RemovePlayerOverlay(Handle timer, int userid) {
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

bool IsInvuln(int client) {
	return (TF2_IsPlayerInCondition(client, TFCond_Ubercharged) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedOnTakeDamage) ||
		TF2_IsPlayerInCondition(client, TFCond_Bonked) ||
		TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode) ||
		!GetEntProp(client, Prop_Data, "m_takedamage"));
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

stock any Min(any a, any b) {
	return a > b ? b : a;
}