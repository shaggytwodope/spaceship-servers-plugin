#pragma semicolon 1

#include <sourcemod>
#include <color_literals>
#include <sourcebanspp>
#undef REQUIRE_PLUGIN
#include <updater>

#define PLUGIN_VERSION  "0.0.2"
#define UPDATE_URL      "https://raw.githubusercontent.com/stephanieLGBT/spaceship-servers-plugin/master/updatefile.txt"

// bracket color
#define bColor "1F1F2A"
// text color
#define tColor "696996"
// actual tag
#define sTag "\x07" ... bColor ... "[" ... "\x07" ... tColor ... "Spaceship Servers" ... "\x07" ... bColor ... "]" ... COLOR_DEFAULT ... " "
// discord link
#define discordLink "discord.gg/Dn4wRu3"
// pretty discord link (colored)
#define pDiscord COLOR_DODGERBLUE ... discordLink ... COLOR_DEFAULT

public Plugin myinfo =
{
    name             =  "Spaceship Servers Plugin",
    author           =  "stephanie",
    description      =  "handles misc stuff for all spaceship servers",
    version          =   PLUGIN_VERSION,
    url              =  "https://steph.anie.dev/"
}

bool hasClientBeenWarned[MAXPLAYERS + 1];
bool clientHasCalladminedAlready[MAXPLAYERS + 1];
Handle g_hCallAdminTimer[MAXPLAYERS + 1];
Handle g_hSpamTimer[MAXPLAYERS + 1];
char hostname[84];

// plugin just started
public OnPluginStart()
{
    HookEvent("player_disconnect", ePlayerLeft);
    // updater
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }

}

public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

public OnMapStart()
{
    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));
    clearAllTimersAllClients();
}

public OnMapEnd()
{
    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));
    clearAllTimersAllClients();
}

// player join
public OnClientPostAdminCheck(Cl)
{
    GetConVarString(FindConVar("hostname"), hostname, sizeof(hostname));
    CreateTimer(10.0, WelcomeClient, GetClientUserId(Cl), TIMER_FLAG_NO_MAPCHANGE);
}

// greet player!
public Action WelcomeClient(Handle timer, int userid)
{
    int Cl = GetClientOfUserId(userid);
    if (IsValidClient(Cl))
    {
        PrintColoredChatAll(sTag ... "Welcome to \x07" ... tColor ... "%s", hostname);
        PrintColoredChatAll(sTag ... "To turn off cross server IRC chat, type " ... COLOR_GREEN ... "/irc" ... COLOR_DEFAULT ... ".");
        PrintColoredChatAll(sTag ... "To summon an admin, type " ... COLOR_MEDIUMPURPLE ... "!calladmin" ... COLOR_DEFAULT ... ". " ... COLOR_RED ... "Please note this can and will result in mutes and/or bans if misused!!!");
        PrintColoredChatAll(sTag ... "To see information about the discord, type " ... COLOR_SKYBLUE ... "!discord" ... COLOR_DEFAULT ... ".");
    }
}

// player fully dc'd
public Action ePlayerLeft(Handle event, char[] name, bool dontBroadcast)
{
    int Cl = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidClient(Cl))
    {
        if (hasClientBeenWarned[Cl] && clientHasCalladminedAlready[Cl])
        {
            char auth[64];
            GetClientAuthId(Cl, AuthId_Engine, auth, sizeof(auth));
            PrintColoredChatAll(sTag ... "User %N left immediately after calling admin. Autobanned for 1 day", Cl);
            SBPP_BanPlayer(0, Cl, 1440, "Autobanned for calladmin abuse");
        }
        clearAllTimersFor(Cl);
    }
}

public Action OnClientSayCommand(int Cl, const char[] command, const char[] sArgs)
{
    if (IsValidClient(Cl))
    {
        if (StrContains(sArgs, "!calladmin", false) != -1)
        {
            if (clientHasCalladminedAlready[Cl])
            {
                // stop fucking spamming
                PrintColoredChat(Cl, sTag ... "Stop spamming! An admin will be with you shortly. If you have not already enabled IRC chat, do so now with " ... COLOR_GREEN ... "/irc" ... COLOR_DEFAULT ... ".");
                return Plugin_Stop;
            }
            else if (!hasClientBeenWarned[Cl])
            {
                PrintColoredChat(Cl, sTag ... "You are about to call an admin. Please note that this " ... COLOR_RED ... "WILL" ... COLOR_DEFAULT ... " result in you being " ... COLOR_RED ... "BANNED" ... COLOR_DEFAULT ... " from the server if you are trolling.");
                PrintColoredChat(Cl, sTag ... "To call an admin, type !calladmin again within a minute. If this is not an urgent issue, please join the Discord over at " ... pDiscord);
                PrintColoredChat(Cl, sTag ... "If you have IRC chat disabled, please turn it on with " ... COLOR_GREEN ... "/irc" ... COLOR_DEFAULT ... " so that admins can communicate with you through our "
                 ... COLOR_SKYBLUE ... "discord to IRC bridge" ... COLOR_DEFAULT ... ".");
                hasClientBeenWarned[Cl] = true;
                g_hCallAdminTimer[Cl]   = null;
                g_hCallAdminTimer[Cl]   = CreateTimer(60.0, calladminTimeout, GetClientUserId(Cl), TIMER_FLAG_NO_MAPCHANGE);
                return Plugin_Stop;
            }
            else if (hasClientBeenWarned[Cl])
            {
                char curTime[32];
                FormatTime(curTime, sizeof(curTime), "%I:%M:%S %p %Z", GetTime());
                ServerCommand("say " ... "client %L calladmined at %s!", Cl, curTime);
                ServerCommand("say " ... "!calladmin", Cl, curTime);
                clientHasCalladminedAlready[Cl] = true;
                clearCAtimeout(Cl, true);
                g_hSpamTimer[Cl]   = null;
                g_hSpamTimer[Cl]   = CreateTimer(360.0, stopSpammingLol, GetClientUserId(Cl), TIMER_FLAG_NO_MAPCHANGE);
                return Plugin_Stop;
            }
        }
        if  (
                StrContains(sArgs, "!discord", false) != -1 || StrContains(sArgs, "/discord", false) != -1
            )
        {
            PrintColoredChat(Cl, sTag ... "Join the Discord over at " ... pDiscord ... "!");
            return Plugin_Stop;
        }
    }
    return Plugin_Continue;
}

clearAllTimersFor(Cl)
{
    clearCAtimeout(Cl, true);
    clearSpamTimer(Cl, true);
}

clearAllTimersAllClients()
{
    for (int Cl = 0; Cl < MaxClients + 1; Cl++)
    {
        if (IsValidClient(Cl))
        {
            clearAllTimersFor(Cl);
        }
    }
}

public Action calladminTimeout(Handle timer, int userid)
{
    int Cl = GetClientOfUserId(userid);
    clearCAtimeout(Cl, false);
}

clearCAtimeout(Cl, bool shutup)
{
    if (IsValidClient(Cl))
    {
        if (g_hCallAdminTimer[Cl] != null)
        {
            KillTimer(g_hCallAdminTimer[Cl]);
            g_hCallAdminTimer[Cl] = null;
        }
        if (!shutup)
        {
            PrintColoredChat(Cl, sTag ... "Calladmin timer expired.");
        }
        hasClientBeenWarned[Cl] = false;
    }
}

public Action stopSpammingLol(Handle timer, int userid)
{
    int Cl = GetClientOfUserId(userid);
    clearSpamTimer(Cl, false);
}

clearSpamTimer(Cl, bool shutup)
{
    if (IsValidClient(Cl))
    {
        if (g_hSpamTimer[Cl] != null)
        {
            KillTimer(g_hSpamTimer[Cl]);
            g_hSpamTimer[Cl] = null;
        }
        if (!shutup)
        {
            PrintColoredChat(Cl, sTag ... "You can now !calladmin again.");
        }
        clientHasCalladminedAlready[Cl] = false;
    }
}

// cleaned up IsAValidClient Stock
stock bool IsValidClient(client)
{
    if  (
            client <= 0
            || client > MaxClients
            || !IsClientConnected(client)
            || IsFakeClient(client)
        )
    {
        return false;
    }
    return IsClientInGame(client);
}