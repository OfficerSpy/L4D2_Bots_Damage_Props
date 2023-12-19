#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

ConVar bots_survivor_damage_props;
ConVar bots_infected_damage_gascans;

public Plugin myinfo = 
{
	name = "[L4D2] Bots Damage Props",
	author = "Officer Spy",
	description = "Allows bots to ignite certain props.",
	version = "1.0.0",
	url = ""
};

public void OnPluginStart()
{
	bots_survivor_damage_props = CreateConVar("sm_bots_survivor_damage_props", "1", "Let survivor bots damage props.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	bots_infected_damage_gascans = CreateConVar("sm_bots_infected_damage_gascans", "1", "Let infected bots damage gas cans.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "weapon_gascan"))
		SDKHook(entity, SDKHook_OnTakeDamage, GasCan_OnTakeDamage);
	
	//TODO: the other exploding props
}

public Action GasCan_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (bots_survivor_damage_props.BoolValue && IsValidSurvivorBot(attacker))
	{
		//Have the bot's weapon be the actual attacker, similar to how it's done in the addon Left4Bots
		SDKHooks_TakeDamage(victim, attacker, GetActiveWeapon(attacker), damage, damagetype, weapon, NULL_VECTOR, damagePosition, true);
		return Plugin_Handled;
	}
	
	if (bots_infected_damage_gascans.BoolValue && IsValidSpitterBot(attacker))
	{
		//Let spitter bots damage only Scavenge gas cans
		if (GetEntProp(victim, Prop_Data, "m_nSkin") == 1)
		{
			//NOTE: Setting the spitter as the inflictor causes the spit damage sound effect when the gas can's fire inflicts
			//damage to survivors. however, it is still just fire (inferno) damage and stops when the acid is gone
			SDKHooks_TakeDamage(victim, attacker, 0, damage, damagetype, weapon, NULL_VECTOR, damagePosition, true);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

public Action PropPhysics_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (bots_survivor_damage_props.BoolValue && IsValidSurvivorBot(attacker) && IsExplosivePropWeapon(victim))
	{
		AcceptEntityInput(victim, "Break", attacker);
		// return Plugin_Handled;
	}
	
	PrintToChatAll("PROP TAKE DAMAGE");
	
	return Plugin_Continue;
}

bool IsValidSurvivorBot(int client)
{
	if (client < 1 || client > MaxClients)
		return false;
	
	if (GetClientTeam(client) != 2) //Survivor team only
		return false;
	
	return IsFakeClient(client);
}

int GetActiveWeapon(int client)
{
	return GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
}

bool IsValidSpitterBot(int client)
{
	if (client < 1 || client > MaxClients)
		return false;
	
	//Infected team only
	if (GetClientTeam(client) != 3)
		return false;
	
	//Spitter only
	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 4)
		return false;
	
	return IsFakeClient(client);
}

//Fireworks, oxygen tank, propane tank
bool IsExplosivePropWeapon(int entity)
{
	//TODO: neither classname nor serverclass name are reliable here, because they change for prop_physics after being dropped by players
	//Find a more reliable way to check these
	
	char model[PLATFORM_MAX_PATH]; GetEntityModelPath(entity, model, sizeof(model));
	
	return StrContains(model, "explosive_box001.mdl") != -1 || StrContains(model, "oxygentank01.mdl") != -1 || StrContains(model, "propanecanister001a.mdl") != -1;
}

//From stocksoup/entity_prop_stocks.inc
stock int GetEntityModelPath(int entity, char[] buffer, int maxlen) {
	return GetEntPropString(entity, Prop_Data, "m_ModelName", buffer, maxlen);
}

/* I think the relevant functions are only calling CBasePlayer::IsBot on the attacker
to determine if the attacker is a bot player and return 0 damage as a result,
so the idea here is to apply damage from a different attacker (but not another player) */