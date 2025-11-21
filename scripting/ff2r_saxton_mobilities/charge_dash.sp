/*
	"special_charge_dash"
	{
		"delay"			"5.0"		// Delay before first use
		"charge"		"1.5"		// Charge time to maximum duration
		"button"		"25"		// Button to Charge
		"velocity"		"1400.0"	// Dash Velocity
		"cooldown"		"10.0"		// Cooldown after use
		"radius"		"130.0"		// Radius to dealing and knockback
		"damage"		"125.0"		// Damage on contact
		
		"weapon_airindex"		"42"	// Weapon index on windup in air. For animation.
		"weapon_groundindex"	"5"		// Weapon index on perform. Set this to original index.
		
		"dash_model"			""		// Visual effect on dash
		
		"windup_anim"			""		// Viewmodel anim on windup
		"charge_anim"			""		// Viewmodel anim on dash
		"end_anim"				""		// Viewmodel anim on finish
		
		"plugin_name"	"ff2r_saxton_mobilities"
	}
	
	"sound_charge_dash"
	{
		"vo/null.mp3"	""
	}
*/
#pragma semicolon 1
#pragma newdecls required

#define DEFINDEX_UNDEFINED 		65535
#define CHARGEDASH_CHARGESOUND "weapons/stickybomblauncher_charge_up.wav"

static Handle ChargeDashHud;

static int CustomDamageChargeDashRef = -1;

static bool ChargeDashEnabled[MAXPLAYERS + 1];
static bool ChargeDashing[MAXPLAYERS + 1];
static char ChargeDashEndAnim[MAXPLAYERS + 1][64];
static float ChargeDashSpeed[MAXPLAYERS + 1];
static bool HitByChargeDash[MAXPLAYERS + 1][MAXPLAYERS + 1];

void ChargeDash_OnPluginStart() {
	ChargeDashHud = CreateHudSynchronizer();
}

void ChargeDash_OnBossCreated(int client, BossData cfg) {
	if (!ChargeDashEnabled[client]) {
		AbilityData ability = cfg.GetAbility("special_charge_dash");
		if (ability.IsMyPlugin()) {
			ChargeDashEnabled[client] = true;
			
			ChargeDash_SetupCustomDamage();
			ability.SetFloat("delay", GetGameTime() + ability.GetFloat("delay", 5.0));
		}
	}
}

void ChargeDash_OnBossRemoved(int client) {
	ChargeDashEnabled[client] = false;
}

static void ChargeDash_SetupCustomDamage() {
	int target = EntRefToEntIndex(CustomDamageChargeDashRef);
	if (target == INVALID_ENT_REFERENCE) {
		CustomDamageChargeDashRef = EntIndexToEntRef(MakeInfoTarget("hale_charge"));
	}
}

void ChargeDash_RemoveCustomDamage() {
	int target = EntRefToEntIndex(CustomDamageChargeDashRef);
	if (target != INVALID_ENT_REFERENCE) {
		RemoveEntity(target);
		CustomDamageChargeDashRef = -1;
	}
}

void ChargeDash_OnPlayerRunCmdPost(int client, int buttons) {
	if (ChargeDashEnabled[client]) {
		BossData boss = FF2R_GetBossData(client);
		AbilityData ability;
		if (boss && (ability = boss.GetAbility("special_charge_dash"))) {
			if (!IsPlayerAlive(client)) {
				return;
			}
			
			if (ChargeDashing[client]) {
				ChargeDash_Bash(client, ability);
			}
			
			float gameTime = GetGameTime();
			bool cooldown = ability.GetBool("incooldown", true);
			float timeIn = ability.GetFloat("delay");
			bool hud;
			
			if (cooldown) {
				if (timeIn < gameTime) {
					cooldown = false;
					timeIn = 0.0;
					
					ability.SetBool("incooldown", cooldown);
					ability.SetFloat("delay", timeIn);
					
					hud = true;
				}
			}
			else if (!MightySlam_IsFalling(client)) {
				bool ground = view_as<bool>(GetEntityFlags(client) & FL_ONGROUND);
				
				float charge = ability.GetFloat("charge", 1.5);
				if (charge < 0.001)
					charge = 0.001;
				
				if (timeIn)
					charge = (gameTime - timeIn) / charge * 100.0;
				
				int button = ability.GetInt("button", 25);
				if (charge < 200.0 && (buttons & (1 << button))) {
					ChargeDash_ChargeUp(client, ability, timeIn, ground);
				}
				else if (timeIn && charge >= 15.0) {
					Rage_ChargeDash(client, ability, timeIn, charge, ground, cooldown);
				}
				else {
					ChargeDash_ClearChargeUpState(client, ability);
					
					timeIn = 0.0;
					ability.SetFloat("delay", 0.0);
				}
			}
			
			if ((hud || ability.GetFloat("hudin") < gameTime) && GameRules_GetRoundState() != RoundState_TeamWin) {
				ability.SetFloat("hudin", gameTime + 0.09);
				
				SetGlobalTransTarget(client);
				if (cooldown) {
					float time = timeIn - gameTime + 0.09;
					if (time < 999.9) {
						SetHudTextParams(-1.0, 0.74, 0.1, 255, 255, 255, 255);
						ShowSyncHudText(client, ChargeDashHud, "%t", "Charge Dash Not Ready", time);
					}
				}
				else {
					int button = ability.GetInt("button", 25);
					char buffer[16];
					Format(buffer, sizeof(buffer), "Short %d", button);
					
					if (timeIn) {
						float charge = (gameTime - timeIn) / ability.GetFloat("charge", 1.5) * 100.0;
						SetHudTextParams(-1.0, 0.74, 0.1, 255, charge < 15.0 ? 255 : 64, charge < 15.0 ? 255 : 64, 255);
						if (charge >= 100.0) {
							ShowSyncHudText(client, ChargeDashHud, "%t", "Charge Dash Charge", buffer, 100);
						}
						else {
							ShowSyncHudText(client, ChargeDashHud, "%t", "Charge Dash Charge", buffer, RoundToCeil(charge));
						}
					}
					else if (button >= 0) {
						SetHudTextParams(-1.0, 0.74, 0.1, 255, 255, 255, 255);
						ShowSyncHudText(client, ChargeDashHud, "%t", "Charge Dash Ready", buffer, 0);
					}
				}
			}
		}
		else {
			ChargeDashEnabled[client] = false;
		}
	}
}

static void ChargeDash_ChargeUp(int client, ConfigData cfg, float& timeIn, bool ground) {
	if (!timeIn) {
		timeIn = GetGameTime();
		cfg.SetFloat("delay", timeIn);
		EmitSoundToAll(CHARGEDASH_CHARGESOUND, client, SNDCHAN_AUTO);
	}
	
	char buffer[64];
	if (cfg.GetString("windup_anim", buffer, sizeof(buffer))) {
		SetViewmodelAnimation(client, buffer);
	}
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, {0.0, 0.0, 0.0});
	if (!TF2_IsPlayerInCondition(client, TFCond_Slowed))
		TF2_AddCondition(client, TFCond_Slowed);
	
	if (!TF2_IsPlayerInCondition(client, TFCond_MegaHeal))
		TF2_AddCondition(client, TFCond_MegaHeal);
	
	int entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (entity != -1) {
		int index = cfg.GetInt("weapon_airindex", -1);
		if (index >= 0 && !ground)
			SetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex", index);
	}
	
	TF2Attrib_AddCustomPlayerAttribute(client, "no_attack", 1.0, 0.5);
	TF2Attrib_AddCustomPlayerAttribute(client, "move speed penalty", 0.25, 0.5);
}

static void Rage_ChargeDash(int client, ConfigData cfg, float& timeIn, float charge, bool ground, bool &cooldown) {
	ChargeDash_ClearChargeUpState(client, cfg);
	if (charge > 100.0) {
		charge = 100.0;
	}
	
	float time = RemapValClamped(charge, 15.0, 100.0, 0.5, cfg.GetFloat("duration", 1.0));
	//float time = charge / 166.0 + 0.4;
	TF2Attrib_AddCustomPlayerAttribute(client, "no_attack", 1.0, time);
	TF2_AddCondition(client, TFCond_HalloweenKartDash, time, client);
	TF2_AddCondition(client, TFCond_BlastJumping, _, client);
	TF2_AddCondition(client, TFCond_AirCurrent, time, client);
	
	float eyeAngles[3], fwd[3];
	GetClientEyeAngles(client, eyeAngles);
	eyeAngles[0] = ground ? eyeAngles[0] - 10.0 : eyeAngles[0];
	GetAngleVectors(eyeAngles, fwd, NULL_VECTOR, NULL_VECTOR);
	ChargeDashSpeed[client] = cfg.GetFloat("velocity", 1400.0);
	ScaleVector(fwd, ChargeDashSpeed[client]);
	
	SetEntPropEnt(client, Prop_Send, "m_hGroundEntity", -1);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fwd);
	SetEntityFlags(client, GetEntityFlags(client) & ~FL_ONGROUND);
	
	SetEntityGravity(client, 0.3);
	
	cfg.GetString("end_anim", ChargeDashEndAnim[client], sizeof(ChargeDashEndAnim[]));
	
	char model[128];
	if (cfg.GetString("dash_model", model, sizeof(model))) {
		PrecacheModel(model);
		CreateChargeDashWearable(client, model, time);
	}
	
	ChargeDashing[client] = true;
	CreateTimer(time, Timer_EndCharge, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	
	for (int i = 1; i <= MaxClients; i++) {
		HitByChargeDash[client][i] = false;
	}
	
	FF2R_EmitBossSoundToAll("sound_charge_dash", client, _, client, _, SNDLEVEL_TRAFFIC);
	
	cooldown = true;
	cfg.SetBool("incooldown", cooldown);
	
	timeIn = GetGameTime() + time + cfg.GetFloat("cooldown", 10.0);
	cfg.SetFloat("delay", timeIn);
}

static void ChargeDash_Bash(int client, ConfigData cfg) {
	char buffer[64];
	if (cfg.GetString("charge_anim", buffer, sizeof(buffer))) {
		SetViewmodelAnimation(client, buffer);
	}
	
	float angles[3], offset[3], fwd[3], pos[3];
	GetClientEyeAngles(client, angles);
	GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);
	offset = fwd;
	ScaleVector(offset, 60.0);
	
	SetEntProp(client, Prop_Send, "m_bJumping", true);
	SetEntPropFloat(client, Prop_Send, "m_flJumpTime", 1.0);
	SetEntPropEnt(client, Prop_Send, "m_hGroundEntity", -1);
	ScaleVector(fwd, ChargeDashSpeed[client]);
	SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fwd);
	
	TF2Util_EntityWorldSpaceCenter(client, pos);
	AddVectors(pos, offset, pos);
	DoDamageChargeDash(client, pos, cfg.GetFloat("damage", 125.0));
	// DoDamageChargeDash(client, pos, cfg.GetFloat("radius", 65.0), cfg.GetFloat("damage", 125.0));
}

static void DoDamageChargeDash(int client, const float pos[3], float damage) {
	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	
	int inflictor = EntRefToEntIndex(CustomDamageChargeDashRef);
	inflictor = inflictor != INVALID_ENT_REFERENCE ? inflictor : client;
	
	static const float DashMins[3] = { -60.0, -60.0, -10.0 };
	static const float DashMaxs[3] = { 60.0, 60.0, 110.0 };
	
	float vecMins[3], vecMaxs[3];
	vecMins[0] = DashMins[0] + pos[0];
	vecMins[1] = DashMins[1] + pos[1];
	vecMins[2] = DashMins[2] + pos[2];
	
	vecMaxs[0] = DashMaxs[0] + pos[0];
	vecMaxs[1] = DashMaxs[1] + pos[1];
	vecMaxs[2] = DashMaxs[2] + pos[2];
	
	static float targetPos[3];
	int entity = -1;
	while ((entity = SDKCall_FindEntityByClassNameWithin(entity, "*", vecMins, vecMaxs)) != -1) {
		if (client != entity && SDKCall_IsEntityCombatCharacter(entity)) {
			if (0 < entity <= MaxClients) {
				if (HitByChargeDash[client][entity]) {
					continue;
				}
				
				HitByChargeDash[client][entity] = true;
				
				float angles[3], fwd[3];
				TF2Util_EntityWorldSpaceCenter(entity, targetPos);
				GetVectorAnglesTwoPoints(pos, targetPos, angles);
				GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);
				
				fwd[0] *= 1250.0;
				fwd[1] *= 1250.0;
				fwd[2] = 425.0;
				
				TE_SetupTFParticleEffect("taunt_headbutt_impact_stars", targetPos);
				TE_SendToAll();
				
				SDKHooks_TakeDamage(entity, inflictor, client, damage, DMG_BURN|DMG_PREVENT_PHYSICS_FORCE, weapon, .bypassHooks = false);
				
				TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, fwd);
			} else {
				TF2Util_EntityWorldSpaceCenter(entity, targetPos);
				
				TE_SetupTFParticleEffect("taunt_headbutt_impact_stars", targetPos);
				TE_SendToAll();
				
				SDKHooks_TakeDamage(entity, inflictor, client, GetEntProp(entity, Prop_Data, "m_iMaxHealth") * 4.0, DMG_BURN|DMG_PREVENT_PHYSICS_FORCE, weapon, .bypassHooks = false);
			}
		}
	}
}

static Action Timer_EndCharge(Handle timer, int userid) {
	int client = GetClientOfUserId(userid);
	if (client && ChargeDashing[client]) {
		ChargeDashing[client] = false;
		
		if (ChargeDashEndAnim[client][0]) {
			SetViewmodelAnimation(client, ChargeDashEndAnim[client]);
		}
		
		TF2_AddCondition(client, TFCond_GrapplingHookLatched);
		SetEntityGravity(client, 1.0);
	}
	return Plugin_Continue;
}

static void ChargeDash_ClearChargeUpState(int client, ConfigData cfg) {
	StopSound(client, SNDCHAN_AUTO, CHARGEDASH_CHARGESOUND);
	int entity = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (entity != -1) {
		int index = cfg.GetInt("weapon_groundindex", -1);
		if (index >= 0)
			SetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex", index);
	}
	
	TF2_RemoveCondition(client, TFCond_Slowed);
	TF2_RemoveCondition(client, TFCond_MegaHeal);
}

static void CreateChargeDashWearable(int client, const char[] model, float lifetime) {
	int wearable = CreateEntityByName("tf_wearable");
	if (IsValidEntity(wearable)) {
		SetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex", DEFINDEX_UNDEFINED);
		DispatchSpawn(wearable);
		
		SetEntityModel(wearable, model);
		SDKCall_EquipWearable(client, wearable);
		
		char buffer[64];
		FormatEx(buffer, sizeof(buffer), "OnUser1 !self:Kill::%.1f:1", lifetime);
		SetVariantString(buffer);
		AcceptEntityInput(wearable, "AddOutput");
		AcceptEntityInput(wearable, "FireUser1");
	}
}

bool ChargeDash_IsDashing(int client) {
	return ChargeDashing[client];
}