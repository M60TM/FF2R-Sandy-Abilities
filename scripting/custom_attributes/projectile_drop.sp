#include <sourcemod>
#include <dhooks>
#include <sdkhooks>
#include <sdktools>

#include <tf_custom_attributes>

DynamicHook g_DHookPhysicsSimulate;

public void OnPluginStart() {
	GameData gameConf = new GameData("tf2.sandy");
	if (!gameConf) {
		SetFailState("Failed to load gamedata(tf2.sandy.txt).");
	}
	
	g_DHookPhysicsSimulate = DynamicHook.FromConf(gameConf, "CBaseEntity::PhysicsSimulate");
	
	delete gameConf;
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (!StrContains(classname, "tf_projectile_rocket")) {
		SDKHook(entity, SDKHook_SpawnPost, Hook_RocketSpawned);
	} else if (!StrContains(classname, "tf_projectile_energy")) {
		SDKHook(entity, SDKHook_SpawnPost, Hook_ProjectileSpawned);
	}
}

public void Hook_RocketSpawned(int entity) {
	int launcher = GetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher");
	if (IsValidEntity(launcher)) {
		float gravity = TF2CustAttr_GetFloat(launcher, "set projectile gravity", 0.0);
		if (gravity > 0.0) {
			SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);
			SetEntityGravity(entity, gravity);
			
			g_DHookPhysicsSimulate.HookEntity(Hook_Post, entity, DHook_OnPhysicsSimulatePost);
		}
		
		gravity = TF2CustAttr_GetFloat(launcher, "projectile launch power", 0.0);
		if (gravity > 0.0) {
			DataPack pack = new DataPack();
			pack.WriteCell(EntIndexToEntRef(entity));
			pack.WriteFloat(gravity);
			RequestFrame(NextFrame_LaunchProjectile, pack);
		}
	}
}

MRESReturn DHook_OnPhysicsSimulatePost(int entity) {
	RequestFrame(NextFrame_DropProjectile, EntIndexToEntRef(entity));
	
	return MRES_Ignored;
}

void NextFrame_DropProjectile(int ref) {
	int entity = EntRefToEntIndex(ref);
	if (IsValidEntity(entity)) {
		float ang[3], vel[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vel);
		
		GetVectorAngles(vel, ang);
		TeleportEntity(entity, NULL_VECTOR, ang, vel);
	}
}

public void Hook_ProjectileSpawned(int entity) {
	int launcher = GetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher");
	if (IsValidEntity(launcher)) {
		float gravity = TF2CustAttr_GetFloat(launcher, "set projectile gravity", 0.0);
		if (gravity > 0.0) {
			SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);
			SetEntityGravity(entity, gravity);
		}
		
		gravity = TF2CustAttr_GetFloat(launcher, "projectile launch power", 0.0);
		if (gravity > 0.0) {
			DataPack pack = new DataPack();
			pack.WriteCell(EntIndexToEntRef(entity));
			pack.WriteFloat(gravity);
			RequestFrame(NextFrame_LaunchProjectile, pack);
		}
	} else {
		int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
		if (owner > 0 && owner <= MaxClients) {
			launcher = GetEntPropEnt(owner, Prop_Send, "m_hActiveWeapon");
			
			if (IsValidEntity(launcher)) {
				float gravity = TF2CustAttr_GetFloat(launcher, "set projectile gravity", 0.0);
				if (gravity > 0.0) {
					SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);
					SetEntityGravity(entity, gravity);
				}
				
				gravity = TF2CustAttr_GetFloat(launcher, "projectile launch power", 0.0);
				if (gravity > 0.0) {
					DataPack pack = new DataPack();
					pack.WriteCell(EntIndexToEntRef(entity));
					pack.WriteFloat(gravity);
					RequestFrame(NextFrame_LaunchProjectile, pack);
				}
			}
		}
	}
}

void NextFrame_LaunchProjectile(DataPack pack) {
	pack.Reset();
	int entity = EntRefToEntIndex(pack.ReadCell());
	float power = pack.ReadFloat();
	delete pack;
	
	if (IsValidEntity(entity)) {
		float ang[3], vel[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vel);
		
		vel[2] += power;
		
		GetVectorAngles(vel, ang);
		TeleportEntity(entity, NULL_VECTOR, ang, vel);
	}
}