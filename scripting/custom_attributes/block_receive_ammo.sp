/*
	enum EAmmoSource
	{
		kAmmoSource_Pickup,					// this came from either a box of ammo or a player's dropped weapon
		kAmmoSource_Resupply,				// resupply cabinet and/or full respawn
		kAmmoSource_DispenserOrCart,		// the player is standing next to an engineer's dispenser or pushing the cart in a payload game
	};
	
	enum ETFAmmoType
	{
		TF_AMMO_DUMMY = 0,	// Dummy index to make the CAmmoDef indices correct for the other ammo types.
		TF_AMMO_PRIMARY,
		TF_AMMO_SECONDARY,
		TF_AMMO_METAL,
		TF_AMMO_GRENADES1,
		TF_AMMO_GRENADES2,
		TF_AMMO_GRENADES3,	// Utility Slot Grenades
		TF_AMMO_COUNT,

		//
		// ADD NEW ITEMS HERE TO AVOID BREAKING DEMOS
		//
	};
*/
#include <sourcemod>
#include <dhooks>

#include <tf_econ_dynamic>
#include <tf2attributes>

#pragma semicolon 1
#pragma newdecls required

public void OnPluginStart() {
	GameData gameConf = new GameData("tf2.sandy");
	if (!gameConf) {
		SetFailState("Failed to load gamedata (tf2.sandy).");
	}
	
	DynamicDetour detourGiveAmmo = DynamicDetour.FromConf(gameConf, "CTFPlayer::GiveAmmo");
	detourGiveAmmo.Enable(Hook_Pre, Detour_GiveAmmo);
	
	delete gameConf;
	
	TF2EconDynAttribute attrib = new TF2EconDynAttribute();
	attrib.SetCustom("hidden", "1");
	
	attrib.SetName("block receive ammo");
	attrib.SetClass("block_receive_ammo");
	attrib.SetCustom("stored_as_integer", "1");
	attrib.SetDescriptionFormat("value_is_additive");
	attrib.Register();
	
	attrib.SetName("block receive ammotype");
	attrib.SetClass("block_receive_ammotype");
	attrib.SetCustom("stored_as_integer", "1");
	attrib.SetDescriptionFormat("value_is_additive");
	attrib.Register();
	
	delete attrib;
}

MRESReturn Detour_GiveAmmo(int client, DHookReturn ret, DHookParam params) {
	int ammoType = params.Get(2);
	int ammoSource = params.Get(4);
	if (TF2Attrib_HookValueInt(0, "block_receive_ammotype", client) & (1 << ammoType)) {
		if (TF2Attrib_HookValueInt(0, "block_receive_ammo", client) & (1 << ammoSource)) {
			ret.Value = 0;
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}