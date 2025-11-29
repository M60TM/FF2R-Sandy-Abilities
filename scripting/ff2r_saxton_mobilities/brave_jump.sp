/*
	"special_brave_jump"
	{
		"slot"			"1"		// Charge slot (Only used for sound_ability)
		"velocity"		"300.0"	// Velocity on jump
		"power"			"850.0"	// Upward velociy on jump
		"delay"			"10.0"	// Delay before first use
		"cooldown"		"7.5"	// Cooldown after use
		"forward"		"1.25"	// Forward velociy bonus on low angle
		"upward"		"1.4"	// Upward velociy bonus on high angle
		
		"plugin_name"	"ff2r_saxton_mobilities"
	}
	
	"sound_ability"
	{
		"saxton_hale/saxton_hale_132_jump_1.wav"		"1"
		"saxton_hale/saxton_hale_132_jump_2.wav"		"1"
		"saxton_hale/saxton_hale_responce_jump1.wav"	"1"
	}
*/
#pragma semicolon 1
#pragma newdecls required

static Handle SyncHud;

static bool BraveJumpEnabled[MAXPLAYERS + 1];

void BraveJump_OnPluginStart() {
	SyncHud = CreateHudSynchronizer();
}

void BraveJump_OnPlayerRunCmdPost(int client, int buttons) {
	if (BraveJumpEnabled[client]) {
		BossData boss = FF2R_GetBossData(client);
		AbilityData ability;
		if (boss && (ability = boss.GetAbility("special_brave_jump"))) {
			if (IsPlayerAlive(client)) {
				float gameTime = GetGameTime();
				bool cooldown = ability.GetBool("incooldown", true);
				float timeIn = ability.GetFloat("delay");
				bool hud;
				
				if (cooldown && timeIn < gameTime) {
					cooldown = false;
					timeIn = 0.0;
					
					ability.SetBool("incooldown", cooldown);
					ability.SetFloat("delay", timeIn);
					
					hud = true;
				}
				
				if (!(buttons & IN_SCORE) &&
					GameRules_GetRoundState() != RoundState_TeamWin &&
					(hud || gameTime > ability.GetFloat("hudin"))) {
					ability.SetFloat("hudin", gameTime + 0.09);
					if (!cooldown) {
						SetHudTextParams(-1.0, 0.88, 0.1, 255, 255, 255, 255);
						ShowSyncHudText(client, SyncHud, "%T", "Double Jump Ready", client);
					}
					else {
						SetHudTextParams(-1.0, 0.88, 0.1, 255, 64, 64, 255);
						ShowSyncHudText(client, SyncHud, "%T", "Double Jump Not Ready", client, timeIn - gameTime + 0.09);
					}
				}
			}
		}
		else {
			BraveJumpEnabled[client] = false;
		}
	}
}

void BraveJump_OnBossCreated(int client, BossData cfg) {
	if (!BraveJumpEnabled[client]) {
		AbilityData ability = cfg.GetAbility("special_brave_jump");
		if (ability.IsMyPlugin()) {
			BraveJumpEnabled[client] = true;
			ability.SetFloat("delay", GetGameTime() + ability.GetFloat("delay", 5.0));
			SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		}
	}
}

void BraveJump_OnBossRemoved(int client) {
	if (BraveJumpEnabled[client]) {
		BraveJumpEnabled[client] = false;
		SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	}
}

static void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom) {
	if (attacker > MaxClients || (!attacker && (inflictor || !(damagetype & DMG_FALL)))) {
		if (BraveJumpEnabled[victim]) {
			BossData boss = FF2R_GetBossData(victim);
			AbilityData ability;
			if (boss && (ability = boss.GetAbility("special_brave_jump"))) {
				if (damage > ability.GetFloat("min_emergency_damage", 100.0)) {
					ability.SetBool("incooldown", false);
					ability.SetFloat("delay", 0.0);
					ability.SetFloat("emergencyfor", GetGameTime() + 0.5);
				}
				return;
			}
			
			BraveJumpEnabled[victim] = false;
		}
		
		SDKUnhook(victim, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	}
}

void BraveJumpFrame(int userid) {
	int client = GetClientOfUserId(userid);
	if (!client) {
		return;
	}
	
	if (!BraveJumpEnabled[client] || ChargeDash_IsDashing(client) || MightySlam_IsFalling(client)) {
		return;
	}
	
	BossData boss = FF2R_GetBossData(client);
	AbilityData ability;
	if (boss && (ability = boss.GetAbility("special_brave_jump"))) {
		float gameTime = GetGameTime();
		if (ability.GetFloat("delay") < gameTime) {
			float velocity = ability.GetFloat("velocity", 300.0);
			
			float angles[3], fwd[3], right[3];
			GetClientEyeAngles(client, angles);
			GetAngleVectors(angles, fwd, right, NULL_VECTOR);
			
			fwd[2] = 0.0;
			NormalizeVector(fwd, fwd);
			
			right[2] = 0.0;
			NormalizeVector(right, right);
			
			float newVel[3];
			newVel[0] = fwd[0];
			newVel[1] = fwd[1];
			NormalizeVector(newVel, newVel);
			ScaleVector(newVel, velocity);
			ScaleVector(newVel, VelBasedOnLowAngle(angles[0], ability.GetFloat("forward", 1.25)));
			
			newVel[2] = ability.GetFloat("power", 700.0) * VelBasedOnHighAngle(angles[0], ability.GetFloat("upward", 1.4));
			
			float curVel[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", curVel);
			if (curVel[2] < velocity)
				curVel[2] = 0.0;
			
			AddVectors(newVel, curVel, newVel);
			SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", newVel);
			
			SetEntProp(client, Prop_Send, "m_bJumping", true);
			TF2Util_SetPlayerBlastJumpState(client, TF_PLAYER_ENEMY_BLASTED_ME, false);
			//TF2_AddCondition(client, TFCond_BlastJumping, _, client);
			
			ability.SetBool("incooldown", true);
			ability.SetFloat("delay", gameTime + ability.GetFloat("cooldown", 8.0));
			ability.SetFloat("hudin", 0.0);
			
			char buffer[8];
			if (ability.GetString("slot", buffer, sizeof(buffer)))
				FF2R_EmitBossSoundToAll("sound_ability", client, buffer, client, _, SNDLEVEL_TRAFFIC);
		}
	}
}