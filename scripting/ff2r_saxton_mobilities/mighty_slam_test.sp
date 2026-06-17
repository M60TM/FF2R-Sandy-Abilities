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
		
		"cooltime"		"5.0"
		"cooldown"		"10.0"
		
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

enum eMightySlamEvent {
	MS_EVENT_COOLDOWN_END,
	MS_EVENT_TOGGLE_READY,
	MS_EVENT_ACTIVATE,
	MS_EVENT_DEACTIVATE,
	MS_EVENT_LANDED,
	MS_EVENT_COOLTIME_RESET
};

enum eMightySlamState {
	MS_STATE_NONE = -1,
	MS_STATE_COOLDOWN = 0,
	MS_STATE_IDLE,
	MS_STATE_READY,
	MS_STATE_WEIGHDOWN,
	MS_STATE_WEIGHDOWN_COOLDOWN,
	MS_STATE_SLAMDOWN,
	
	MS_STATE_MAX
};

enum eMightySlamAction {
	MS_ACTION_NONE = 0,
	
	MS_ACTION_WEIGHDOWN,
	MS_ACTION_SLAMDOWN,
	MS_ACTION_LAND,
	MS_ACTION_SLAM,
	MS_ACTION_CANCEL_SLAMDOWN,
	
	MS_ACTION_MAX
};

enum eMightySlamActionType {
	MS_ACTION_TYPE_NONE,
	MS_ACTION_TYPE_ONLYCLIENT,
	MS_ACTION_TYPE_CONFIG
}

typeset MightySlamActionFunc {
	function void(int client);
	function void(int client, ConfigData cfg);
}

/**
 * Action table for mighty slam
 * 
 * @note You cannot use function handle on static definition.
 */
enum struct SlamActionTable {
	eMightySlamState curState;
	eMightySlamEvent event;
	eMightySlamAction action;
	eMightySlamActionType type;
	eMightySlamState nextState;
}

static SlamActionTable ActionTables[] = {
	{MS_STATE_COOLDOWN, MS_EVENT_COOLDOWN_END, MS_ACTION_NONE, MS_ACTION_TYPE_NONE, MS_STATE_IDLE},
	{MS_STATE_COOLDOWN, MS_EVENT_ACTIVATE, MS_ACTION_WEIGHDOWN, MS_ACTION_TYPE_CONFIG, MS_STATE_WEIGHDOWN_COOLDOWN},
	
	{MS_STATE_IDLE, MS_EVENT_TOGGLE_READY, MS_ACTION_NONE, MS_ACTION_TYPE_NONE, MS_STATE_READY},
	{MS_STATE_IDLE, MS_EVENT_ACTIVATE, MS_ACTION_WEIGHDOWN, MS_ACTION_TYPE_CONFIG, MS_STATE_WEIGHDOWN},
	
	{MS_STATE_READY, MS_EVENT_TOGGLE_READY, MS_ACTION_NONE, MS_ACTION_TYPE_NONE, MS_STATE_IDLE},
	{MS_STATE_READY, MS_EVENT_ACTIVATE, MS_ACTION_SLAMDOWN, MS_ACTION_TYPE_CONFIG, MS_STATE_SLAMDOWN},
	
	{MS_STATE_WEIGHDOWN, MS_EVENT_LANDED, MS_ACTION_LAND, MS_ACTION_TYPE_ONLYCLIENT, MS_STATE_IDLE},
	
	{MS_STATE_WEIGHDOWN_COOLDOWN, MS_EVENT_COOLDOWN_END, MS_ACTION_NONE, MS_ACTION_TYPE_NONE, MS_STATE_WEIGHDOWN},
	{MS_STATE_WEIGHDOWN_COOLDOWN, MS_EVENT_LANDED, MS_ACTION_LAND, MS_ACTION_TYPE_ONLYCLIENT, MS_STATE_COOLDOWN},
	
	{MS_STATE_SLAMDOWN, MS_EVENT_LANDED, MS_ACTION_SLAM, MS_ACTION_TYPE_CONFIG, MS_STATE_COOLDOWN},
	{MS_STATE_SLAMDOWN, MS_EVENT_TOGGLE_READY, MS_ACTION_CANCEL_SLAMDOWN, MS_ACTION_TYPE_CONFIG, MS_STATE_IDLE},
	{MS_STATE_SLAMDOWN, MS_EVENT_DEACTIVATE, MS_ACTION_CANCEL_SLAMDOWN, MS_ACTION_TYPE_CONFIG, MS_STATE_READY}
};

static Handle SlamHud;

static int CustomDamageMightySlamRef = -1;
static int CustomDamageMightySlamCollateralRef = -1;

static eMightySlamState CurState[MAXPLAYERS + 1] = { MS_STATE_NONE, ... };

static bool MightySlamPressed[MAXPLAYERS + 1];

static float MightySlamLastGravity[MAXPLAYERS + 1] = {-69.42, ...};
static float MightySlamCurrentGravity[MAXPLAYERS + 1];

/**
 * @noreturn
 */
void MightySlam_OnPluginStart() {
	SlamHud = CreateHudSynchronizer();
}

/**
 * Create hud synchronizer on plugin start.
 * 
 * @param client Client index.
 * @param cfg    BossData configuration.
 * 
 * @noreturn
 */
void MightySlam_OnBossCreated(int client, BossData cfg) {
	if (CurState[client] != MS_STATE_NONE)
		return;
	
	AbilityData ability = cfg.GetAbility("special_mighty_slam");
	if (!ability.IsMyPlugin())
		return;
	
	MightySlam_SetupCustomDamage();
	
	float cooltime = ability.GetFloat("cooltime", 5.0);
	if (cooltime > 0.0) {
		ability.SetFloat("cooltime", GetGameTime() + cooltime);
		MightySlam_SetState(client, MS_STATE_COOLDOWN);
	}
	else {
		MightySlam_SetState(client, MS_STATE_IDLE);
	}
}

void MightySlam_OnBossRemoved(int client) {
	MightySlamPressed[client] = false;
	MightySlam_SetState(client, MS_STATE_NONE);
	
	if (MightySlamLastGravity[client] != -69.42) {
		MightySlam_RestoreGravity(client);
	}
}

void MightySlam_OnClientDisconnected(int client) {
	MightySlamLastGravity[client] = -69.42;
}

void MightySlam_OnPlayerRunCmdPost(int client, int buttons, const float angles[3]) {
	if (CurState[client] != MS_STATE_NONE) {
		BossData boss = FF2R_GetBossData(client);
		AbilityData ability;
		if (boss && (ability = boss.GetAbility("special_mighty_slam"))) {
			if (!IsPlayerAlive(client)) {
				return;
			}
			
			MightySlam_Think(client, ability, buttons, angles[0]);
		}
		else {
			MightySlam_SetState(client, MS_STATE_NONE);
		}
	}
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

//-----
// State Machine.
//-----

/**
 * Directly set current player state.
 * 
 * @param client	Client index.
 * @param state		State to transition.
 * 
 * @noreturn
 */
static void MightySlam_SetState(int client, eMightySlamState state) {
	if (CurState[client] != state) {
		CurState[client] = state;
	}
}

/**
 * Find next state and action to transition from event.
 * 
 * @param client
 * @param state
 * 
 * @noreturn
 */
static void MightySlam_FireEvent(int client, ConfigData cfg, eMightySlamEvent event) {
	eMightySlamState curState = CurState[client];
	for (int i = 0; i < sizeof(ActionTables); i++) {
		if (curState != ActionTables[i].curState || event != ActionTables[i].event)
			continue;
		
		MightySlam_CallActionFunction(client, cfg, ActionTables[i].action, ActionTables[i].type);
		
		CurState[client] = ActionTables[i].nextState;
		break;
	}
}

static void MightySlam_CallActionFunction(int client, ConfigData cfg, eMightySlamAction action, eMightySlamActionType type) {
	MightySlamActionFunc func = INVALID_FUNCTION;
	switch (action) {
		case MS_ACTION_WEIGHDOWN: { func = MightySlam_Weighdown; }
		case MS_ACTION_SLAMDOWN: { func = MightySlam_Slamdown; }
		case MS_ACTION_LAND: { func = MightySlam_Landed; }
		case MS_ACTION_SLAM: { func = MightySlam_Slam; }
		case MS_ACTION_CANCEL_SLAMDOWN: { func = MightySlam_Cancel; }
	}
	
	if (func != INVALID_FUNCTION) {
		switch (type) {
			case MS_ACTION_TYPE_ONLYCLIENT: {
				Call_StartFunction(null, func);
				Call_PushCell(client);
				Call_Finish();
			}
			
			case MS_ACTION_TYPE_CONFIG: {
				Call_StartFunction(null, func);
				Call_PushCell(client);
				Call_PushCell(cfg);
				Call_Finish();
			}
		}
	}
}

/**
 * General think function for mighty slam.
 * 1. Handle event likes press button.
 * 2. Check landing while falling
 * 3. Update HUD for client.
 * 
 * @param client
 * @param cfg
 * @param buttons
 * @param angles
 * 
 * @noreturn
 */
static void MightySlam_Think(int client, ConfigData cfg, int buttons, float angles) {
	bool hud;
	MightySlam_HandleEvent(client, cfg, buttons, hud);
	
	switch (CurState[client]) {
		case MS_STATE_COOLDOWN, MS_STATE_IDLE, MS_STATE_READY: {
			if (MightySlam_CanWeighdown(client, buttons, angles)) {
				float minHeight = (CurState[client] == MS_STATE_READY)
					? cfg.GetFloat("slam_height", 400.0)
					: cfg.GetFloat("height",      250.0);
				
				if (MightySlam_CheckHeight(client, minHeight))
					MightySlam_FireEvent(client, cfg, MS_EVENT_ACTIVATE);
			}
		}
		
		case MS_STATE_SLAMDOWN, MS_STATE_WEIGHDOWN, MS_STATE_WEIGHDOWN_COOLDOWN: {
			int flags = GetEntityFlags(client);
			MightySlam_Falling(client, cfg, buttons, flags);
		}
	}
	
	if (!(buttons & IN_SCORE) && (hud || cfg.GetFloat("hudin") < GetGameTime()) && GameRules_GetRoundState() != RoundState_TeamWin) {
		MightySlam_UpdateHud(client, cfg);
	}
}

static void MightySlam_HandleEvent(int client, ConfigData cfg, int buttons, bool &hud) {
	switch (CurState[client]) {
		case MS_STATE_COOLDOWN, MS_STATE_WEIGHDOWN_COOLDOWN: {
			// Do nothing except cooldown.
			float gameTime = GetGameTime();
			float timeIn = cfg.GetFloat("cooltime");
			bool cooldown = cfg.GetBool("incooldown", true);
			if (cooldown && timeIn < gameTime) {
				cooldown = false;
				timeIn = 0.0;
				
				cfg.SetBool("incooldown", cooldown);
				cfg.SetFloat("cooltime", timeIn);
				
				hud = true;
				
				MightySlam_FireEvent(client, cfg, MS_EVENT_COOLDOWN_END);
			}
		}
		
		case MS_STATE_IDLE, MS_STATE_READY, MS_STATE_SLAMDOWN: {
			int button = cfg.GetInt("button", 13);
			if (MightySlamPressed[client]) {
				if (!(buttons & (1 << button)))
					MightySlamPressed[client] = false;
			}
			else {
				if (buttons & (1 << button)) {
					MightySlamPressed[client] = true;
					MightySlam_FireEvent(client, cfg, MS_EVENT_TOGGLE_READY);
					ClientCommand(client, "playgamesound weapons/vaccinator_toggle.wav");
					hud = true;
				}
			}
		}
	}
}

static void MightySlam_Falling(int client, ConfigData cfg, int buttons, int flags) {
	if ((flags & FL_ONGROUND) || (flags & (FL_SWIM|FL_INWATER))) {
		MightySlam_FireEvent(client, cfg, MS_EVENT_LANDED);
	}
	else {
		if (CurState[client] == MS_STATE_SLAMDOWN && !MightySlam_CanWeighdown(client, buttons, 90.0)) {
			MightySlam_FireEvent(client, cfg, MS_EVENT_DEACTIVATE);
		}
	}
}

static void MightySlam_UpdateHud(int client, ConfigData cfg) {
	float gameTime = GetGameTime();
	cfg.SetFloat("hudin", gameTime + 0.09);
	
	SetGlobalTransTarget(client);
	switch (CurState[client]) {
		case MS_STATE_COOLDOWN, MS_STATE_WEIGHDOWN_COOLDOWN: {
			float timeIn = cfg.GetFloat("cooltime");
			float time = timeIn - gameTime + 0.09;
			if (time < 999.9) {
				SetHudTextParams(-1.0, 0.78, 0.1, 255, 255, 255, 255);
				ShowSyncHudText(client, SlamHud, "%t", "Mighty Slam Cooldown", time);
			}
		}
		case MS_STATE_READY, MS_STATE_SLAMDOWN: {
			char buffer[16];
			int button = cfg.GetInt("button", 13);
			Format(buffer, sizeof(buffer), "Short %d", button);
			
			SetHudTextParams(-1.0, 0.78, 0.1, 255, 64, 64, 255);
			ShowSyncHudText(client, SlamHud, "%t", "Mighty Slam Ready", buffer);
		}
		default: {
			char buffer[16];
			int button = cfg.GetInt("button", 13);
			Format(buffer, sizeof(buffer), "Short %d", button);
			
			SetHudTextParams(-1.0, 0.78, 0.1, 255, 255, 255, 255);
			ShowSyncHudText(client, SlamHud, "%t", "Mighty Slam Not Ready", buffer);
		}
	}
}

//-----
// Action Functions.
//-----

static void MightySlam_Weighdown(int client, ConfigData cfg) {	
	MightySlam_BeginFall(client, cfg.GetFloat("gravity", 4.0));
}

static void MightySlam_Slamdown(int client, ConfigData cfg) {
	MightySlam_Setup(client, cfg);
	MightySlam_BeginFall(client, cfg.GetFloat("slam_gravity", 4.0));
}

static void MightySlam_Landed(int client) {
	MightySlam_RestoreGravity(client);
}

static void MightySlam_Slam(int client, ConfigData cfg) {
	MightySlam_RestoreGravity(client);
	Rage_MightySlam(client, cfg);
	MightySlam_UpdateHud(client, cfg);
}

static void MightySlam_Cancel(int client, ConfigData cfg) {
	MightySlam_RestoreGravity(client);
	MightySlam_ClearSlamdown(client, cfg.GetInt("weapon_index", -1));
}

//

static void MightySlam_BeginFall(int client, float gravity) {
	MightySlamLastGravity[client] = GetEntityGravity(client);
	MightySlamCurrentGravity[client] = gravity;
	SetEntityGravity(client, MightySlamCurrentGravity[client]);
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
		TE_SetupTFParticleEffect(buffer, pos1, .attachType = PATTACH_CUSTOMORIGIN);
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
	MightySlam_ClearSlamdown(client, cfg.GetInt("weapon_index", -1));
	
	cfg.SetBool("incooldown", true);
	cfg.SetFloat("cooltime", GetGameTime() + cfg.GetFloat("cooldown", 10.0));
	
	MakeShake(pos1, cfg.GetFloat("amplitude", 10.0), radius, cfg.GetFloat("duration", 2.0), cfg.GetFloat("frequency", 255.0));
}

static void MightySlam_ClearSlamdown(int client, int index) {
	if (index == -1)
		return;
	
	int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (!IsValidEntity(activeWeapon))
		return;
	
	SetEntProp(activeWeapon, Prop_Send, "m_iItemDefinitionIndex", index);
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

static void MightySlam_Setup(int client, ConfigData cfg) {
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

static bool MightySlam_CanWeighdown(int client, int buttons, float angles) {
	return (buttons & IN_DUCK)
			&& !ChargeDash_IsDashing(client)
			&& !ChargeDash_IsChargeUp(client)
			&& angles > 60.0
			&& !TF2_IsPlayerInCondition(client, TFCond_Dazed)
			&& GetEntityMoveType(client) != MOVETYPE_NONE;
}

bool MightySlam_IsFalling(int client) {
	// return MightySlamLastGravity[client] != -69.42;
	return (CurState[client] == MS_STATE_SLAMDOWN || CurState[client] == MS_STATE_WEIGHDOWN);
}

/*
static void MightySlam_FireEvent(int client, ConfigData cfg, eMightySlamEvent event) {
	eMightySlamState prev = CurState[client];
	eMightySlamState next = prev;
	eMightySlamAction action = MS_ACTION_NONE;
	
	switch (prev) {
		case MS_STATE_COOLDOWN: {
			if (event == MS_EVENT_COOLTIME_END) {
				next = MS_STATE_IDLE;
				action = MS_ACTION_COOLTIME_END;
			}
		}

		case MS_STATE_IDLE: {
			switch (event) {
				case MS_EVENT_PRESS_RELOAD: {
					next = MS_STATE_READY;
					action = MS_ACTION_READY;
				}
				case MS_EVENT_ACTIVATE: {
					next = MS_STATE_WEIGHDOWN;
					action = MS_ACTION_WEIGHDOWN;
				}
			}
		}

		case MS_STATE_READY: {
			switch (event) {
				case MS_EVENT_PRESS_RELOAD: {
					next = MS_STATE_IDLE;
					action = MS_ACTION_UNREADY;
				}
				case MS_EVENT_ACTIVATE: {
					next = MS_STATE_SLAMDOWN;
					action = MS_ACTION_SLAMDOWN;
				}
			}
		}

		case MS_STATE_WEIGHDOWN: {
			if (event == MS_EVENT_LANDED) {
				next = MS_STATE_IDLE;
				action = MS_ACTION_LAND;
			}
		}

		case MS_STATE_SLAMDOWN: {
			switch (event) {
				case MS_EVENT_LANDED:     { next = MS_STATE_COOLDOWN; }  // Slam 발동 → 쿨타임
				case MS_EVENT_DEACTIVATE: { next = MS_STATE_READY; }
			}
		}
	}
	
	if (next != prev) {
		MightySlam_OnStateExit(client, cfg, prev, next);
		CurState[client] = next;
		MightySlam_OnStateEnter(client, cfg, prev, next);
	}
}

static void MightySlam_OnStateExit(int client, ConfigData cfg, eMightySlamState from, eMightySlamState to) {
	switch (from) {
		case MS_STATE_WEIGHDOWN, MS_STATE_SLAMDOWN: {
			MightySlam_RestoreGravity(client);
		}
	}
}

static void MightySlam_OnStateEnter(int client, ConfigData cfg, eMightySlamState from, eMightySlamState to) {
	switch (to) {
		case MS_STATE_WEIGHDOWN: {
			MightySlam_Weighdown(client, cfg.GetFloat("gravity", 4.0));
		}
		
		case MS_STATE_SLAMDOWN: {
			MightySlam_Setup(client, cfg);
			MightySlam_Weighdown(client, cfg.GetFloat("slam_gravity", 4.0));
		}
		
		case MS_STATE_READY: {
			switch (from) {
				case MS_STATE_IDLE: {
					
				}
				case MS_STATE_SLAMDOWN: {
					
				}
			}
		}
	}
}
*/