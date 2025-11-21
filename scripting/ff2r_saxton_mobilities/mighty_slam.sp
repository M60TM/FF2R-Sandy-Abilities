/*
	"special_mighty_slam"
	{
		"button"		"13"
		"gravity"		"6.0"
		"particle"		"hammer_impact_button_dust2"
		"radius"		"400.0"
		"force"			"650.0"
		"damage"		"300.0"
		"decay"			"1.0"
		
		"amplitude"		"10.0"
		"duration"		"2.0"
		"frequency"		"255.0"
		
		"slam_index"	"-1"
		"start_anim"	""
		"pound_anim"	""
		
		"plugin_name"	"ff2r_saxton_mobilities"
	}
	
	"sound_mighty_slam"
	{
		"vo/null.mp3"	""
	}
*/
#pragma semicolon 1
#pragma newdecls required

static Handle SlamHud;

static int CustomDamageMightySlamRef = -1;
static int CustomDamageMightySlamCollateralRef = -1;

static bool MightySlamEnabled[MAXPLAYERS + 1];
static bool MightySlamActivated[MAXPLAYERS + 1];
static float MightySlamLastGravity[MAXPLAYERS + 1] = {-69.42, ...};
static float MightySlamCurrentGravity[MAXPLAYERS + 1];

void MightySlam_OnPluginStart() {
	SlamHud = CreateHudSynchronizer();
}

void MightySlam_OnBossCreated(int client, BossData cfg) {
	if (!MightySlamEnabled[client]) {
		AbilityData ability = cfg.GetAbility("special_mighty_slam");
		if (ability.IsMyPlugin()) {
			MightySlamEnabled[client] = true;
			
			MightySlam_SetupCustomDamage();
			ability.SetFloat("cooltime", GetGameTime() + ability.GetFloat("cooltime", 5.0));
		}
	}
}

void MightySlam_OnBossRemoved(int client) {
	MightySlamEnabled[client] = false;
	MightySlamActivated[client] = false;
	
	if (MightySlamLastGravity[client] != -69.42) {
		MightySlam_RestoreGravity(client);
	}
}

void MightySlam_OnClientDisconnected(int client) {
	MightySlamLastGravity[client] = -69.42;
}

static void MightySlam_SetupCustomDamage() {
	int target = EntRefToEntIndex(CustomDamageMightySlamRef);
	if (target == INVALID_ENT_REFERENCE) {
		CustomDamageMightySlamRef = EntIndexToEntRef(MakeInfoTarget("hale_slam"));
	}
	
	target = EntRefToEntIndex(CustomDamageMightySlamCollateralRef);
	if (target == INVALID_ENT_REFERENCE) {
		CustomDamageMightySlamCollateralRef = EntIndexToEntRef(MakeInfoTarget("hale_slam_collateral"));
	}
}

void MightySlam_RemoveCustomDamage() {
	int target = EntRefToEntIndex(CustomDamageMightySlamRef);
	if (target != INVALID_ENT_REFERENCE) {
		RemoveEntity(target);
		CustomDamageMightySlamRef = -1;
	}
	
	target = EntRefToEntIndex(CustomDamageMightySlamCollateralRef);
	if (target != INVALID_ENT_REFERENCE) {
		RemoveEntity(target);
		CustomDamageMightySlamCollateralRef = -1;
	}
}

void MightySlam_OnPlayerRunCmdPost(int client, int buttons, const float angles[3]) {
	if (MightySlamEnabled[client]) {
		BossData boss = FF2R_GetBossData(client);
		AbilityData ability;
		if (boss && (ability = boss.GetAbility("special_mighty_slam"))) {
			if (!IsPlayerAlive(client)) {
				return;
			}
			
			float gameTime = GetGameTime();
			float timeIn = ability.GetFloat("cooltime");
			bool cooldown = ability.GetBool("incooldown", true);
			bool hud;
			
			if (cooldown && timeIn < gameTime) {
				cooldown = false;
				timeIn = 0.0;
				
				ability.SetBool("incooldown", cooldown);
				ability.SetFloat("cooltime", timeIn);
				
				hud = true;
			}
			
			int flags = GetEntityFlags(client);
			if (MightySlamLastGravity[client] != -69.42) {
				hud = MightySlam_CheckFalling(client, ability, buttons, flags, cooldown);
			}
			else {
				MightySlam_Weighdown(client, ability, flags, angles[0]);
			}
			
			if (!(buttons & IN_SCORE) && (hud || ability.GetFloat("hudin") < gameTime) && GameRules_GetRoundState() != RoundState_TeamWin) {
				ability.SetFloat("hudin", gameTime + 0.09);
				
				SetGlobalTransTarget(client);
				if (cooldown) {
					float time = timeIn - gameTime + 0.09;
					if (time < 999.9) {
						SetHudTextParams(-1.0, 0.78, 0.1, 255, 255, 255, 255);
						ShowSyncHudText(client, SlamHud, "%t", "Mighty Slam Not Ready", time);
					}
				}
				else {
					int button = ability.GetInt("button", 13);
					char buffer[16];
					Format(buffer, sizeof(buffer), "Short %d", button);
					
					SetHudTextParams(-1.0, 0.78, 0.1, 255, 64, 64, 255);
					ShowSyncHudText(client, SlamHud, "%t", "Mighty Slam Ready", buffer);
				}
			}
		}
		else {
			MightySlamEnabled[client] = false;
		}
	}
}

static bool MightySlam_CheckFalling(int client, ConfigData cfg, int buttons, int flags, bool cooldown) {
	if ((flags & FL_ONGROUND) || (flags & (FL_SWIM|FL_INWATER))) {
		MightySlam_RestoreGravity(client);
		
		if (MightySlamActivated[client]) {
			MightySlamActivated[client] = false;
			Rage_MightySlam(client, cfg);
			
			return true;
		}
	}
	/*
	else if ((!(flags & FL_DUCKING))
		|| ChargeDash_IsDashing(client)
		|| TF2_IsPlayerInCondition(client, TFCond_Dazed)
		|| GetEntityMoveType(client) == MOVETYPE_NONE) {
	*/
	else if (!MightySlam_CanWeighdown(client, flags, 90.0)) {
		MightySlam_RestoreGravity(client);
		MightySlam_ResetState(client, cfg.GetInt("weapon_index", -1));
	}
	else if (!MightySlamActivated[client] && !cooldown) {
		int button = cfg.GetInt("button", 13);
		if ((buttons & (1 << button)) && MightySlam_CheckHeight(client, cfg.GetFloat("slam_height", 450.0))) {
			MightySlam_Ready(client, cfg);
		}
	}
	
	return false;
}

static void MightySlam_Weighdown(int client, ConfigData cfg, int flags, float angles) {
	if (!((flags & FL_ONGROUND) || (flags & (FL_SWIM|FL_INWATER)))
		&& MightySlam_CanWeighdown(client, flags, angles) && MightySlam_CheckHeight(client, cfg.GetFloat("height", 250.0))) {
		MightySlamLastGravity[client] = GetEntityGravity(client);
		MightySlamCurrentGravity[client] = cfg.GetFloat("gravity", 4.0);
		SetEntityGravity(client, MightySlamCurrentGravity[client]);
	}
}

static void Rage_MightySlam(int client, ConfigData cfg) {
	static float pos1[3], pos2[3];
	TF2Util_EntityWorldSpaceCenter(client, pos1);
	
	float damage = cfg.GetFloat("damage", 300.0);
	float radius = cfg.GetFloat("radius", 400.0);
	float force = cfg.GetFloat("force", 650.0);
	float decay = cfg.GetFloat("decay", 0.5) * damage;
	
	char buffer[64];
	if (cfg.GetString("particle", buffer, sizeof(buffer), "hammer_impact_button_dust2")) {
		TE_SetupTFParticleEffect(buffer, pos1);
		TE_SendToAll();
	}
	
	if (cfg.GetString("pound_anim", buffer, sizeof(buffer))) {
		SetViewmodelAnimation(client, buffer);
	}
	
	FF2R_EmitBossSoundToAll("sound_mighty_slam", client, .origin = pos1);
	
	if (damage > 0.0) {
		int inflictor = EntRefToEntIndex(CustomDamageMightySlamRef);
		inflictor = inflictor != INVALID_ENT_REFERENCE ? inflictor : client;
		
		int victim = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
		if (SDKCall_IsEntityCombatCharacter(victim)) {
			SDKHooks_TakeDamage(victim, inflictor, client, damage, DMG_SLASH|DMG_PREVENT_PHYSICS_FORCE, -1, .bypassHooks = false);
		}
		
		inflictor = EntRefToEntIndex(CustomDamageMightySlamCollateralRef);
		inflictor = inflictor != INVALID_ENT_REFERENCE ? inflictor : client;
		int target = -1;
		float distance;
		while ((target = SDKCall_FindEntityInSphere(target, pos1, radius)) != -1) {
			if (target != client && target != victim && SDKCall_IsEntityCombatCharacter(target)) {
				TF2Util_EntityWorldSpaceCenter(target, pos2);
				distance = GetVectorDistance(pos1, pos2);
				
				SDKHooks_TakeDamage(target, inflictor, client, RemapValClamped(distance, 0.0, radius, damage, decay), DMG_SLASH|DMG_PREVENT_PHYSICS_FORCE, -1, .bypassHooks = false);
			}
		}
	}
	
	SDKCall_PushAllPlayersAway(pos1, radius, force, GetClientTeam(client));
	
	int index = cfg.GetInt("weapon_index", -1);
	if (index != -1) {
		int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (IsValidEntity(activeWeapon)) {
			SetEntProp(activeWeapon, Prop_Send, "m_iItemDefinitionIndex", index);
		}
	}
	
	cfg.SetBool("incooldown", true);
	cfg.SetFloat("cooltime", GetGameTime() + cfg.GetFloat("cooldown", 10.0));
	
	MakeShake(pos1, cfg.GetFloat("amplitude", 10.0), radius, cfg.GetFloat("duration", 2.0), cfg.GetFloat("frequency", 255.0));
}

static void MightySlam_ResetState(int client, int index) {
	if (!MightySlamActivated[client])
		return;
	
	MightySlamActivated[client] = false;
	if (index == -1)
		return;
	
	int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (IsValidEntity(activeWeapon)) {
		SetEntProp(activeWeapon, Prop_Send, "m_iItemDefinitionIndex", index);
	}
}

static bool MightySlam_CheckHeight(int client, float height) {
	float pos1[3], pos2[3];
	GetClientAbsOrigin(client, pos1);
	pos2 = pos1;
	pos2[2] -= height;
	TR_TraceRayFilter(pos1, pos2, MASK_PLAYERSOLID, RayType_EndPoint, TraceRay_DontHitSelf, client);
	return !TR_DidHit();
}

static void MightySlam_RestoreGravity(int client) {
	if (GetEntityGravity(client) == MightySlamCurrentGravity[client])
		SetEntityGravity(client, MightySlamLastGravity[client]);
	
	MightySlamLastGravity[client] = -69.42;
}

static void MightySlam_Ready(int client, ConfigData cfg) {
	MightySlamActivated[client] = true;
	
	int index = cfg.GetInt("slam_index", -1);
	if (index != -1) {
		int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (IsValidEntity(activeWeapon)) {
			SetEntProp(activeWeapon, Prop_Send, "m_iItemDefinitionIndex", index);
		}
	}
	
	char buffer[64];
	if (cfg.GetString("start_anim", buffer, sizeof(buffer))) {
		SetViewmodelAnimation(client, buffer);
	}
}

static bool MightySlam_CanWeighdown(int client, int flags, float angles) {
	return (flags & FL_DUCKING)
			&& !ChargeDash_IsDashing(client)
			&& angles > 60.0
			&& !TF2_IsPlayerInCondition(client, TFCond_Dazed)
			&& GetEntityMoveType(client) != MOVETYPE_NONE;
}

bool MightySlam_IsFalling(int client) {
	return MightySlamLastGravity[client] != -69.42;
}