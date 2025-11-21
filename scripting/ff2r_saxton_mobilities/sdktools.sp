#pragma semicolon 1
#pragma newdecls required

static Handle SDKEquipWearable;
static Handle SDKPushAllPlayersAway;
static Handle SDKFindEntityInSphere;
static Handle SDKFindEntityByClassNameWithin;
static Handle SDKGetCombatCharacterPtr;

void SDKCall_Setup() {
	GameData gamedata = new GameData("sm-tf2.games");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(gamedata.GetOffset("RemoveWearable") - 1);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	SDKEquipWearable = EndPrepSDKCall();
	if(!SDKEquipWearable)
		LogError("[Gamedata] Could not find RemoveWearable");
	
	delete gamedata;
	
	gamedata = new GameData("ff2r.sandy");
	if (!gamedata) {
		SetFailState("Failed to load gamedata (ff2r.sandy).");
	}
	
	StartPrepSDKCall(SDKCall_GameRules);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFGameRules::PushAllPlayersAway");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	SDKPushAllPlayersAway = EndPrepSDKCall();
	
	if (!SDKPushAllPlayersAway) {
		SetFailState("[Gamedata] Could not find CTFGameRules::PushAllPlayersAway");
	}
	
	StartPrepSDKCall(SDKCall_EntityList);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature,
			"CGlobalEntityList::FindEntityInSphere");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer,
			VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	SDKFindEntityInSphere = EndPrepSDKCall();

	if (!SDKFindEntityInSphere) {
		SetFailState("[Gamedata] Could not find CGlobalEntityList::FindEntityInSphere");
	}
	
	StartPrepSDKCall(SDKCall_EntityList);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature,
			"CGlobalEntityList::FindEntityByClassnameWithin");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer,
			VDECODE_FLAG_ALLOWNULL | VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	SDKFindEntityByClassNameWithin = EndPrepSDKCall();
	
	if (!SDKFindEntityByClassNameWithin) {
		SetFailState("[Gamedata] Could not find CGlobalEntityList::FindEntityByClassnameWithin");
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual,
			"CBaseEntity::MyCombatCharacterPointer");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	SDKGetCombatCharacterPtr = EndPrepSDKCall();

	if (!SDKGetCombatCharacterPtr) {
		SetFailState("[Gamedata] Could not find CBaseEntity::MyCombatCharacterPointer");
	}
	
	delete gamedata;
}

void SDKCall_EquipWearable(int client, int entity) {
	if (SDKEquipWearable) {
		SDKCall(SDKEquipWearable, client, entity);
	} else {
		RemoveEntity(entity);
	}
}

void SDKCall_PushAllPlayersAway(const float pos[3], float radius, float force, int team) {
	if (SDKPushAllPlayersAway && radius > 0.0 && force > 0.0)
		SDKCall(SDKPushAllPlayersAway, pos, radius, force, team == 2 ? 3 : 2, 0);
}

int SDKCall_FindEntityInSphere(int startEntity, const float pos[3], float radius) {
	return SDKCall(SDKFindEntityInSphere, startEntity, pos, radius, Address_Null);
}

int SDKCall_FindEntityByClassNameWithin(int startEntity, const char[] classname, const float vecMins[3], const float vecMaxs[3]) {
	return SDKCall(SDKFindEntityByClassNameWithin, startEntity, classname, vecMins, vecMaxs, Address_Null);
}

bool SDKCall_IsEntityCombatCharacter(int entity) {
	return SDKCall(SDKGetCombatCharacterPtr, entity) != Address_Null;
}

