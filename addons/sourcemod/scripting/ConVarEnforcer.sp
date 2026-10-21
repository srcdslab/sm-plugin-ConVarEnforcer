#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <ConVarEnforcer>

#define VERSION "1.1"

#undef REQUIRE_PLUGIN
#include <adminmenu>

#pragma newdecls required

public Plugin myinfo = 
{
	name        = "ConVar Enforcer",
	author      = "blacky",
	description = "Enforces certain ConVars that won't work through server.cfg",
	version     = VERSION,
	url         = "http://steamcommunity.com/id/blaackyy/"
}

ArrayList g_hCvarList;
ArrayList g_hValueList;

TopMenu g_hAdminMenu;

ConVar g_hCvarEnfEnabled;
bool g_bCvarEnfEnabled;

public void OnPluginStart()
{
	CreateConVar("cvarenf_version", VERSION, "ConVar Enforcer version", FCVAR_NOTIFY|FCVAR_REPLICATED);
	g_hCvarEnfEnabled = CreateConVar("cvarenf_enable", "1", "Enables ConVar Enforcer.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarEnfEnabled.AddChangeHook(OnCvarEnfEnabledChanged);
	
	g_hCvarList = new ArrayList(ByteCountToCells(256));
	g_hValueList = new ArrayList(ByteCountToCells(256));
	
	EnforceAllCvars(0);
	
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}
}

public void OnCvarEnfEnabledChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bCvarEnfEnabled = convar.BoolValue;
}

public void OnConfigsExecuted()
{
	g_bCvarEnfEnabled = g_hCvarEnfEnabled.BoolValue;
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
		g_hAdminMenu = null;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
	{
		TopMenu topmenu;
		if((topmenu = GetAdminTopMenu()) != null)
		{
			OnAdminMenuReady(topmenu);
		}
	}
}

public void OnAdminMenuReady(Handle topmenu)
{
	if (topmenu == g_hAdminMenu)
		return;

	g_hAdminMenu = TopMenu.FromHandle(topmenu);
	TopMenuObject serverCmds = g_hAdminMenu.FindCategory(ADMINMENU_SERVERCOMMANDS);
	g_hAdminMenu.AddItem("reloadcvars", TopMenuHandler, serverCmds, "reloadcvars", ADMFLAG_CONFIG);
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
		File hFile = OpenFile(sPath, "r");
		
		if(hFile != null)
		{		
			// Unhook convar changes in case the cvarenf.cfg is being reloaded 
			char sCvar[256];
			int iSize = g_hCvarList.Length;
			ConVar c;
			for(int idx; idx < iSize; idx++)
			{
				g_hCvarList.GetString(idx, sCvar, sizeof(sCvar));
				
				c = FindConVar(sCvar);
				
				if(c != null)
				{
					c.RemoveChangeHook(OnConVarChanged);
					delete c;
				}
			}
			
			g_hCvarList.Clear();
			g_hValueList.Clear();
			
			// Reload cvarenf.cfg
			char sLine[256], sLineExploded[2][256];
			while(!hFile.EndOfFile())
			{
				hFile.ReadLine(sLine, sizeof(sLine))
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
	
	int iSize = g_hCvarList.Length;
	for(int idx; idx < iSize; idx++)
	{
		g_hCvarList.GetString(idx, sCvarListCvar, sizeof(sCvarListCvar));
		
		if(StrEqual(sCvarName, sCvarListCvar))
		{
			g_hValueList.GetString(idx, sValue, sizeof(sValue));
			
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
		c.AddChangeHook(OnConVarChanged);
		
		g_hCvarList.PushString(sCvar);
		g_hValueList.PushString(sValue);
		
		char sCurrentValue[128];
		c.GetString(sCurrentValue, sizeof(sCurrentValue));
		if(!StrEqual(sValue, sCurrentValue))
		{
			c.SetString(sValue);
		}
		
		delete c;
	}
}

public int Native_Enforce(Handle plugin, int numParams)
{
	char sCvar[128];
	GetNativeString(1, sCvar, sizeof(sCvar));
	
	char sValue[128];
	GetNativeString(2, sValue, sizeof(sValue));
	
	EnforceConVar(sCvar, sValue);
	return 0;
}

public any Native_Unenforce(Handle plugin, int numParams)
{
	char sCvar[128];
	GetNativeString(1, sCvar, sizeof(sCvar));
	
	int idx = g_hCvarList.FindString(sCvar);
	
	if(idx != -1)
	{
		ConVar c = FindConVar(sCvar);
		if(c != null)
		{
			FindConVar(sCvar).RemoveChangeHook(OnConVarChanged);
			delete c;
		}
		
		g_hCvarList.Erase(idx);
		g_hValueList.Erase(idx);
	}
	
	return idx != -1;
}

public any Native_IsEnforced(Handle plugin, int numParams)
{
	char sCvar[128];
	GetNativeString(1, sCvar, sizeof(sCvar));
	
	int idx = g_hCvarList.FindString(sCvar);
	
	return idx != -1;
}