#pragma semicolon 1
#pragma newdecls required

static Handle SDKGetMaxHealth;
static Handle SDKRemoveAllCustomAttribute;

void SDKCall_Setup() {
	GameData gamedata = new GameData("sdkhooks.games");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	SDKGetMaxHealth = EndPrepSDKCall();
	if (!SDKGetMaxHealth)
		LogError("[Gamedata] Could not find GetMaxHealth");
	
	delete gamedata;
	
	gamedata = new GameData("ff2r.sandy");
	if (!gamedata)
		SetFailState("Failed to load gamedata (ff2r.sandy).");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::RemoveAllCustomAttributes");
	SDKRemoveAllCustomAttribute = EndPrepSDKCall();
	if (!SDKRemoveAllCustomAttribute)
		LogError("[Gamedata] Could not find CTFPlayer::RemoveAllCustomAttributes");
	
	delete gamedata;
}

int SDKCall_GetClientMaxHealth(int client) {
	return SDKGetMaxHealth ? SDKCall(SDKGetMaxHealth, client) : GetEntProp(client, Prop_Data, "m_iMaxHealth");
}

void SDKCall_RemoveAllCustomAttribute(int client) {
	if (SDKRemoveAllCustomAttribute)
		SDKCall(SDKRemoveAllCustomAttribute, client);
}