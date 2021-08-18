#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ConVarEnforcer>

#define VERSION "1.0"

#undef REQUIRE_PLUGIN
#include <adminmenu>

public Plugin:myinfo = 
{
	name        = "ConVar Enforcer",
	author      = "blacky",
	description = "Enforces certain ConVars that won't work through server.cfg",
	version     = VERSION,
	url         = "http://steamcommunity.com/id/blaackyy/"
}

ArrayList g_hCvarList;
ArrayList g_hValueList;

Handle g_hAdminMenu;

ConVar g_hCvarEnfEnabled;
bool g_bCvarEnfEnabled;

public void OnPluginStart()
{
	CreateConVar("cvarenf_version", VERSION, "ConVar Enforcer version", FCVAR_NOTIFY|FCVAR_REPLICATED);
	g_hCvarEnfEnabled = CreateConVar("cvarenf_enable", "1", "Enables ConVar Enforcer.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	HookConVarChange(g_hCvarEnfEnabled, OnCvarEnfEnabledChanged);
	
	g_hCvarList = new ArrayList(ByteCountToCells(256));
	g_hValueList = new ArrayList(ByteCountToCells(256));
	
	EnforceAllCvars(0);
	
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
}

public void OnCvarEnfEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bCvarEnfEnabled = GetConVarBool(convar);
}

public void OnConfigsExecuted()
{
	g_bCvarEnfEnabled = GetConVarBool(g_hCvarEnfEnabled);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Cvar_Enforce", Native_Enforce);
	CreateNative("Cvar_Unenforce", Native_Unenforce);
	CreateNative("Cvar_IsEnforced", Native_IsEnforced);
	
	RegPluginLibrary("cvarenf");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
		g_hAdminMenu = INVALID_HANDLE;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
	{
		TopMenu topmenu;
		if((topmenu = GetAdminTopMenu()) != INVALID_HANDLE)
		{
			OnAdminMenuReady(topmenu);
		}
	}
}

public void OnAdminMenuReady(Handle topmenu)
{
	if (topmenu == g_hAdminMenu)
		return;

	g_hAdminMenu = topmenu;
	TopMenuObject serverCmds = FindTopMenuCategory(g_hAdminMenu, ADMINMENU_SERVERCOMMANDS);
	AddToTopMenu(g_hAdminMenu, "reloadcvars", TopMenuObject_Item, TopMenuHandler, serverCmds, "reloadcvars", ADMFLAG_CONFIG);
}

public void TopMenuHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "Reload cvarenf.cfg");

	else if (action == TopMenuAction_SelectOption)
		EnforceAllCvars(param);
}

public void EnforceAllCvars(int client)
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/cvarenf.cfg");
	
	if(FileExists(sPath))
	{
		Handle hFile = OpenFile(sPath, "r");
		
		if(hFile != null)
		{		
			// Unhook convar changes in case the cvarenf.cfg is being reloaded 
			char sCvar[256];
			int iSize = GetArraySize(g_hCvarList);
			ConVar c;
			for(int idx; idx < iSize; idx++)
			{
				GetArrayString(g_hCvarList, idx, sCvar, sizeof(sCvar));
				
				c = FindConVar(sCvar);
				
				if(c != null)
				{
					UnhookConVarChange(c, OnConVarChanged);
					delete c;
				}
			}
			
			ClearArray(g_hCvarList);
			ClearArray(g_hValueList);
			
			// Reload cvarenf.cfg
			char sLine[256], sLineExploded[2][256];
			while(!IsEndOfFile(hFile))
			{
				ReadFileLine(hFile, sLine, sizeof(sLine))
				if(strlen(sLine) > 0)
				{
					ReplaceString(sLine, sizeof(sLine), "\n", "");
					ExplodeString(sLine, " ", sLineExploded, sizeof(sLineExploded), sizeof(sLineExploded[]), true);
					ReplaceString(sLineExploded[0], sizeof(sLineExploded[]), "\"", "");
					ReplaceString(sLineExploded[1], sizeof(sLineExploded[]), "\"", "");
					
					EnforceConVar(sLineExploded[0], sLineExploded[1]);
				}
			}
			
			ReplyToCommand(client, "[SM] cvarenf.cfg reloaded.");
			
			delete hFile;
		}
		else
		{
			ReplyToCommand(client, "[SM] cvarenf.cfg could not be opened.");
		}
	}
	else
	{
		ReplyToCommand(client, "[SM] configs/cvarenf.cfg was not found.");
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(g_bCvarEnfEnabled == false)
	{
		return;
	}
	
	char sCvarName[256], sCvarListCvar[256], sValue[256];
	convar.GetName(sCvarName, sizeof(sCvarName));
	
	int iSize = GetArraySize(g_hCvarList);
	for(int idx; idx < iSize; idx++)
	{
		GetArrayString(g_hCvarList, idx, sCvarListCvar, sizeof(sCvarListCvar));
		
		if(StrEqual(sCvarName, sCvarListCvar))
		{
			GetArrayString(g_hValueList, idx, sValue, sizeof(sValue));
			
			if(!StrEqual(newValue, sValue))
			{
				convar.SetString(sValue);
			}
		}
	}
}

void EnforceConVar(const char[] sCvar, const char[] sValue)
{
	ConVar c = FindConVar(sCvar);
	
	if(c != null)
	{
		HookConVarChange(c, OnConVarChanged);
		
		PushArrayString(g_hCvarList, sCvar);
		PushArrayString(g_hValueList, sValue);
		
		char sCurrentValue[128];
		c.GetString(sCurrentValue, sizeof(sCurrentValue));
		if(!StrEqual(sValue, sCurrentValue))
		{
			c.SetString(sValue);
		}
		
		delete c;
	}
}

public Native_Enforce(Handle plugin, int numParams)
{
	char sCvar[128];
	GetNativeString(1, sCvar, sizeof(sCvar));
	
	char sValue[128];
	GetNativeString(2, sValue, sizeof(sValue));
	
	EnforceConVar(sCvar, sValue);
}

public Native_Unenforce(Handle plugin, int numParams)
{
	char sCvar[128];
	GetNativeString(1, sCvar, sizeof(sCvar));
	
	int idx = FindStringInArray(g_hCvarList, sCvar);
	
	if(idx != -1)
	{
		ConVar c = FindConVar(sCvar);
		if(c != null)
		{
			UnhookConVarChange(FindConVar(sCvar), OnConVarChanged);
			delete c;
		}
		
		RemoveFromArray(g_hCvarList, idx);
		RemoveFromArray(g_hValueList, idx);
	}
	
	return idx != -1;
}

public Native_IsEnforced(Handle plugin, int numParams)
{
	char sCvar[128];
	GetNativeString(1, sCvar, sizeof(sCvar));
	
	int idx = FindStringInArray(g_hCvarList, sCvar);
	
	return idx != -1;
}