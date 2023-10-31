#pragma semicolon 1
#pragma newdecls required

#include <multicolors>
#include <discordWebhookAPI>

#undef REQUIRE_PLUGIN
#tryinclude <ExtendedDiscord>
#define REQUIRE_PLUGIN

#define PLUGIN_NAME "CIDR Block Discord"
#define WEBHOOK_URL_MAX_SIZE			1000
#define WEBHOOK_THREAD_NAME_MAX_SIZE	100

ConVar g_cvWebhook, g_cvWebhookRetry, g_cvHostName, g_cvAvatar, g_cvUsername;
ConVar g_cvChannelType, g_cvThreadName, g_cvThreadID;

char g_sServerName[128];
bool g_Plugin_ExtDiscord = false;

public Plugin myinfo = 
{
	name        = PLUGIN_NAME,
	author      = ".Rushaway",
	description = "CIDR Block Discord",
	version     = "1.0",
	url         = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("CIDR_Discord");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvWebhook = CreateConVar("sm_cidr_discord_webhook", "", "The webhook URL of your Discord channel.", FCVAR_PROTECTED);
	g_cvWebhookRetry = CreateConVar("sm_cidr_discord_webhook_retry", "3", "Number of retries if webhook fails.", FCVAR_PROTECTED);
	g_cvAvatar = CreateConVar("sm_cidr_discord_avatar", "https://avatars.githubusercontent.com/u/110772618?s=200&v=4", "URL to Avatar image.");
	g_cvUsername = CreateConVar("sm_cidr_discord_username", "CIDR Discord", "Discord username.");
	g_cvChannelType = CreateConVar("sm_cidr_discord_channel_type", "0", "Type of your channel: (1 = Thread, 0 = Classic Text channel");

	/* Thread config */
	g_cvThreadName = CreateConVar("sm_cidr_discord_threadname", "CDIR - New Block", "The Thread Name of your Discord forums. (If not empty, will create a new thread)", FCVAR_PROTECTED);
	g_cvThreadID = CreateConVar("sm_cidr_discord_threadid", "0", "If thread_id is provided, the message will send in that thread.", FCVAR_PROTECTED);
	AutoExecConfig(true);

	g_cvHostName = FindConVar("hostname");
}

public void OnAllPluginsLoaded()
{
	g_Plugin_ExtDiscord = LibraryExists("ExtendedDiscord");
}

public void OnLibraryAdded(const char[] sName)
{
	if (strcmp(sName, "ExtendedDiscord", false) == 0)
		g_Plugin_ExtDiscord = true;
}

public void OnLibraryRemoved(const char[] sName)
{
	if (strcmp(sName, "ExtendedDiscord", false) == 0)
		g_Plugin_ExtDiscord = false;
}

public void OnConfigsExecuted()
{
	GetConVarString(g_cvHostName, g_sServerName, sizeof(g_sServerName));
}

public void CIDR_OnActionPerformed(int client, int timestamp, char[] sAction)
{
	char sWebhookURL[WEBHOOK_URL_MAX_SIZE];
	g_cvWebhook.GetString(sWebhookURL, sizeof sWebhookURL);
	if(!sWebhookURL[0]) {
		LogError("[%s] No webhook found or specified.", PLUGIN_NAME);
		return;
	}

	char sTime[64];
	FormatTime(sTime, sizeof(sTime), "%d/%m/%Y @ %H:%M:%S", timestamp);
	
	char sMessage[1999];
	Format(sMessage, sizeof(sMessage), "```Action performed on: %s \nAction perfomed at: %s \n%s```", g_sServerName, sTime, sAction);
	ReplaceString(sMessage, sizeof(sMessage), "\\n", "\n");

	SendWebHook(sMessage, sWebhookURL);
}

stock void SendWebHook(char sMessage[1999], char sWebhookURL[WEBHOOK_URL_MAX_SIZE])
{
	Webhook webhook = new Webhook(sMessage);

	char sThreadID[32], sThreadName[WEBHOOK_THREAD_NAME_MAX_SIZE];
	g_cvThreadID.GetString(sThreadID, sizeof sThreadID);
	g_cvThreadName.GetString(sThreadName, sizeof sThreadName);

	bool IsThread = g_cvChannelType.BoolValue;

	if (IsThread) {
		if (!sThreadName[0] && !sThreadID[0]) {
			LogError("[%s] Thread Name or ThreadID not found or specified.", PLUGIN_NAME);
			delete webhook;
			return;
		} else {
			if (strlen(sThreadName) > 0) {
				webhook.SetThreadName(sThreadName);
				sThreadID[0] = '\0';
			}
		}
	}

	/* Webhook UserName */
	char sName[128];
	g_cvUsername.GetString(sName, sizeof(sName));

	/* Webhook Avatar */
	char sAvatar[256];
	g_cvAvatar.GetString(sAvatar, sizeof(sAvatar));

	if (strlen(sName) > 0)
		webhook.SetUsername(sName);
	if (strlen(sAvatar) > 0)
		webhook.SetAvatarURL(sAvatar);

	DataPack pack = new DataPack();

	if (IsThread && strlen(sThreadName) <= 0 && strlen(sThreadID) > 0)
		pack.WriteCell(1);
	else
		pack.WriteCell(0);
	pack.WriteString(sMessage);
	pack.WriteString(sWebhookURL);

	webhook.Execute(sWebhookURL, OnWebHookExecuted, pack, sThreadID);
	delete webhook;
}

public void OnWebHookExecuted(HTTPResponse response, DataPack pack)
{
	static int retries = 0;
	char sMessage[1999], sWebhookURL[WEBHOOK_URL_MAX_SIZE];

	pack.Reset();
	bool IsThreadReply = pack.ReadCell();
	pack.ReadString(sMessage, sizeof(sMessage));
	pack.ReadString(sWebhookURL, sizeof(sWebhookURL));
	delete pack;
	
	if (!IsThreadReply && response.Status != HTTPStatus_OK) {
		if (retries < g_cvWebhookRetry.IntValue) {
			PrintToServer("[%s] Failed to send the webhook. Resending it .. (%d/%d)", PLUGIN_NAME, retries, g_cvWebhookRetry.IntValue);
			SendWebHook(sMessage, sWebhookURL);
			retries++;
			return;
		} else {
		#if defined _extendeddiscord_included
			if (g_Plugin_ExtDiscord)
				ExtendedDiscord_LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
			else
				LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
		#else
			LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
		#endif
		}
	}
	else if (IsThreadReply && response.Status != HTTPStatus_NoContent)
	{
		if (retries < g_cvWebhookRetry.IntValue)
		{
			PrintToServer("[%s] Failed to send the webhook. Resending it .. (%d/%d)", PLUGIN_NAME, retries, g_cvWebhookRetry.IntValue);
			SendWebHook(sMessage, sWebhookURL);
			retries++;
			return;
		} else {
		#if defined _extendeddiscord_included
			if (g_Plugin_ExtDiscord)
				ExtendedDiscord_LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
			else
				LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
		#else
			LogError("[%s] Failed to send the webhook after %d retries, aborting.", PLUGIN_NAME, retries);
		#endif
		}
	}

	retries = 0;
}