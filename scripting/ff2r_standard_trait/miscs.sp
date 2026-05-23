#pragma semicolon 1
#pragma newdecls required

static int SpecialParticleRef[MAXPLAYERS + 1] = { -1, ... };

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
					float value = ParseExpr(buffer[0], Formula_BasicValue, alive);
					float duration = ParseExpr(buffer[1], Formula_BasicValue, alive);
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
	ClearBossParticle(client);
	
	ConfigData cfgParticle = cfg.GetSection("particles");
	StringMapSnapshot snap = cfgParticle.Snapshot();
	
	int entries = snap.Length;
	if (entries > 0) {
		char model[PLATFORM_MAX_PATH];
		GetClientModel(client, model, sizeof(model));
		
		int prop = CreateEntityByName("prop_dynamic_override");
		if (IsValidEntity(prop)) {
			DispatchKeyValue(prop, "model", model);
			SetEntityCollisionGroup(prop, 1);
			DispatchSpawn(prop);
			
			SetEntProp(prop, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_PARENT_ANIMATES|EF_NOSHADOW|EF_NORECEIVESHADOW);
			SetEntPropEnt(prop, Prop_Send, "m_hOwnerEntity", client);
			
			SetEntityRenderMode(prop, RENDER_TRANSALPHA);
			SetEntityRenderColor(prop, 0, 0, 0, 0);
			
			SetVariantString("!activator");
			AcceptEntityInput(prop, "SetParent", client, prop);
			
			SetVariantString("head");
			AcceptEntityInput(prop, "SetParentAttachment");
			
			SetEntityTransmitState(prop, FL_EDICT_ALWAYS, true);
			
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
						int attachpoint = LookupEntityAttachment(prop, point);
						if (attachpoint) {
							TE_Particle(particle, NULL_VECTOR, _, _, prop, attachtype, attachpoint, false, .delay = -1.0);
						}
					}
					else {
						TE_Particle(particle, NULL_VECTOR, _, _, prop, attachtype, _, false, .delay = -1.0);
					}
				}
			}
			
			SpecialParticle[client] = true;
			SpecialParticleRef[client] = EntIndexToEntRef(prop);
			// Gives enough times to particle can be fully appeared.
			CreateTimer(0.5, Timer_ApplySetTransmit, SpecialParticleRef[client], TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	delete snap;
}

static Action Timer_ApplySetTransmit(Handle timer, int ref) {
	// Entity reference here
	int entity = EntRefToEntIndex(ref);
	if (entity != INVALID_ENT_REFERENCE) {
		SetEntityTransmitState(entity, FL_EDICT_FULLCHECK, true);
		DHook_AlwaysTransmitEntity(entity);
		SDKHook(entity, SDKHook_SetTransmit, AttachEnt_SetTransmit);
	}
	
	return Plugin_Continue;
}

static Action AttachEnt_SetTransmit(int attachEnt, int client) {
	int owner = GetEntPropEnt(attachEnt, Prop_Send, "m_hOwnerEntity");
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

void ClearBossParticle(int client) {	
	int entity = EntRefToEntIndex(SpecialParticleRef[client]);
	if (entity != INVALID_ENT_REFERENCE) {
		if (GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity") == client) {
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
	SpecialParticle[client] = false;
	SpecialParticleRef[client] = -1;
}

/*
void ApplyBossParticle(int client, ConfigData cfg) {
	ClearBossParticle(client);
	
	ConfigData cfgParticle = cfg.GetSection("particles");
	StringMapSnapshot snap = cfgParticle.Snapshot();
	
	int entries = snap.Length;
	if (entries > 0) {
		char model[PLATFORM_MAX_PATH];
		GetClientModel(client, model, sizeof(model));
		
		int wearable = CreateEntityByName("tf_wearable");
		if (IsValidEntity(wearable)) {
			SetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex", DEFINDEX_UNDEFINED);
			SetEntProp(wearable, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL|EF_NOSHADOW|EF_NORECEIVESHADOW);
			SetEntPropEnt(wearable, Prop_Send, "m_hOwnerEntity", client);
			
			DispatchSpawn(wearable);
			
			SetEntityModel(wearable, model);
			SetEntProp(wearable, Prop_Send, "m_bValidatedAttachedEntity", true);
			
			SetEntityRenderMode(wearable, RENDER_TRANSALPHA);
			SetEntityRenderColor(wearable, 0, 0, 0, 0);
			
			TF2Util_EquipPlayerWearable(client, wearable);
			
			// SetEntityTransmitState(wearable, FL_EDICT_ALWAYS, true);
			
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
						int attachpoint = LookupEntityAttachment(wearable, point);
						if (attachpoint) {
							TE_Particle(particle, NULL_VECTOR, _, _, wearable, attachtype, attachpoint, false);
							//TE_SetupTFParticleEffect(particle, NULL_VECTOR, _, _, prop, attachtype, attachpoint, false);
							//TE_SendToAll(0.0);
						}
					}
					else {
						TE_Particle(particle, NULL_VECTOR, _, _, wearable, attachtype, _, false);
						//TE_SetupTFParticleEffect(particle, NULL_VECTOR, _, _, prop, attachtype, -1, false);
						//TE_SendToAll(0.0);
					}
				}
			}
			
			SpecialParticle[client] = true;
			//SpecialParticleRef[client] = EntIndexToEntRef(wearable);
			// Gives enough times to particle can be fully appeared.
			CreateTimer(0.5, Timer_ApplySetTransmit, EntIndexToEntRef(wearable), TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	delete snap;
}
*/