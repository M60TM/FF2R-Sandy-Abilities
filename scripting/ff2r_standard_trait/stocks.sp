#pragma semicolon 1
#pragma newdecls required

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
	
	return ParseExpr(buffer, Formula_BasicValue, float(players));
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

/*
stock void TE_SendToAllNotMe(int client, float delay=0.0)
{
	int total = 0;
	int[] clients = new int[MaxClients];
	for (int i=1; i<=MaxClients; i++)
	{
		if (i != client && IsClientInGame(i))
		{
			clients[total++] = i;
		}
	}
	TE_Send(clients, total, delay);
}
*/

/*
bool IsInvuln(int client) {
	return (TF2_IsPlayerInCondition(client, TFCond_Ubercharged) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedCanteen) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedHidden) ||
		TF2_IsPlayerInCondition(client, TFCond_UberchargedOnTakeDamage) ||
		TF2_IsPlayerInCondition(client, TFCond_Bonked) ||
		TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode) ||
		!GetEntProp(client, Prop_Data, "m_takedamage"));
}
*/

stock int SetEntityTransmitState(int entity, int newFlags, bool isSetFlag = false) {
	if (!IsValidEdict(entity))
		return 0;
	
	int flags = GetEdictFlags(entity);
	flags &= ~(FL_EDICT_ALWAYS | FL_EDICT_PVSCHECK | FL_EDICT_DONTSEND);
	flags |= newFlags;
	if (isSetFlag)
		SetEdictFlags(entity, flags);

	return flags;
}

stock void TE_Particle(const char[] name, const float vecOrigin[3] = NULL_VECTOR, 
		const float vecStart[3] = NULL_VECTOR, const float vecAngles[3] = NULL_VECTOR,
		int entity = -1, ParticleAttachment_t attachType = PATTACH_ABSORIGIN,
		int attachPoint = -1, bool bResetParticles = false, 
		int customColors = 0, const float vecColor1[3] = NULL_VECTOR,
		const float vecColor2[3] = NULL_VECTOR, int controlPoint = -1, int controlPointAttachment = -1, float controlPointOffset[3] = NULL_VECTOR, float delay = 0.0) {
	int particleTable, particleIndex;
	
	if ((particleTable = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE) {
		ThrowError("Could not find string table: ParticleEffectNames");
	}
	
	if ((particleIndex = FindStringIndex(particleTable, name)) == INVALID_STRING_INDEX) {
		ThrowError("Could not find particle index: %s", name);
	}
	
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", vecOrigin[0]);
	TE_WriteFloat("m_vecOrigin[1]", vecOrigin[1]);
	TE_WriteFloat("m_vecOrigin[2]", vecOrigin[2]);
	TE_WriteFloat("m_vecStart[0]", vecStart[0]);
	TE_WriteFloat("m_vecStart[1]", vecStart[1]);
	TE_WriteFloat("m_vecStart[2]", vecStart[2]);
	TE_WriteVector("m_vecAngles", vecAngles);
	TE_WriteNum("m_iParticleSystemIndex", particleIndex);
	
	TE_WriteNum("entindex", entity);
	
	if (attachType != PATTACH_ABSORIGIN)
		TE_WriteNum("m_iAttachType", view_as<int>(attachType));
	
	if (attachPoint != -1)
		TE_WriteNum("m_iAttachmentPointIndex", attachPoint);
	
	TE_WriteNum("m_bResetParticles", bResetParticles ? 1 : 0);
	if (customColors) {
		TE_WriteNum("m_bCustomColors", customColors);
		TE_WriteVector("m_CustomColors.m_vecColor1", vecColor1);
		if (customColors == 2)
			TE_WriteVector("m_CustomColors.m_vecColor2", vecColor2);
	}

	if (controlPoint != -1) {
		TE_WriteNum("m_bControlPoint1", controlPoint);
		if (controlPointAttachment != -1) {
			TE_WriteNum("m_ControlPoint1.m_eParticleAttachment", controlPointAttachment);
			TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", controlPointOffset[0]);
			TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", controlPointOffset[1]);
			TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", controlPointOffset[2]);
		}
	}

	TE_SendToAll(delay);
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

void Formula_BasicValue(const char[] var_name, int var_name_len, float &f, any data)
{
	if(CharToLower(var_name[0]) == 'n' || CharToLower(var_name[0]) == 'x')
		f = data;
}