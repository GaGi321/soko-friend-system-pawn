// =======================================//
/*
		Friend System aka Singer for SA:MP 0.3.7-R2 Server
		Created at: 20.12.2024.

		Developed by Dragan Avdic (Dragi)
		Credits:
			- BlueG


		Iako sam mogao komplikovanije uraditi, uradjeno je olaksano i bez finti(trikova) DONEKLE zbog pocetnika
		iako ne preporucujem svezim pocetnicima ovaj rad zbog slozenijih SQL upita i logike.

		Unesete komandu '/prijatelji' i tu vam je celokupan basic sistem. Dodao sam da mozete poslati SMS direktno prijatelju,
		ali to je u fazi razvoja, odnosno vi ubacite vas gde sam tacno oznacio. Sistem mozete uvek unaprediti i dodati 1000 opcija...

		Pored standardnih threaded asinhronih upita, odlucio sam se da ubacim 2 unthreaded query-a
		i ni pod tackom razno NE PREPORUCUJEM cackanje toga jer moze doci do obaranja memorije sistema!


		*Useful Functions aka 'uf.inc' sam ubacio jer su mi trebale 2-3 funkcije, mogao sam ih direktno implementirati
		ali zbog daljeg razvoja sam implementirao biblioteku. Koriscenje funkcije su prepravljene od strane mene, originale su bile ubagovane
		i nece vam raditi ako ne skinete ovaj moj 'uf.inc'
*/
// =======================================//


// -----------------------------------------------------------------------------
// Includes
// --------

#include 	<a_samp>

#undef	  	MAX_PLAYERS
#define	 	MAX_PLAYERS			50

#include 	<a_mysql>
#include    <samp_bcrypt>
#include 	<sscanf2>
#include 	<Pawn.CMD>
#include 	<uf>

// -----------------------------------------------------------------------------
// Defines
// -------

// MySQL configuration
#define		MYSQL_HOST 			"localhost"
#define		MYSQL_USER 			"root"
#define		MYSQL_PASSWORD 		""
#define		MYSQL_DATABASE 		"filterscript"

// how many seconds until it kicks the player for taking too long to login
#define		SECONDS_TO_LOGIN 	30

// default spawn point: Las Venturas (The High Roller)
#define 	DEFAULT_POS_X 		1958.3783
#define 	DEFAULT_POS_Y 		1343.1572
#define 	DEFAULT_POS_Z 		15.3746
#define 	DEFAULT_POS_A 		270.1425

#define C_WHITE            		"{FFFFFF}"
#define C_GREEN          		"{6EF83C}"
#define C_RED          			"{F81414}"
#define C_BLUE 					"{0049FF}"
#define C_SCRVENA				"{FF6347}"
#define C_SOKO					"{2674c0}"


/*
	######## ##    ## ##     ## ##     ##  ######  
	##       ###   ## ##     ## ###   ### ##    ## 
	##       ####  ## ##     ## #### #### ##       
	######   ## ## ## ##     ## ## ### ##  ######  
	##       ##  #### ##     ## ##     ##       ## 
	##       ##   ### ##     ## ##     ## ##    ## 
	######## ##    ##  #######  ##     ##  ###### 
*/


// player data
enum E_PLAYERS
{
	ID,
	Name[MAX_PLAYER_NAME],
	Password[61], 
	Float: X_Pos,
	Float: Y_Pos,
	Float: Z_Pos,
	Float: A_Pos,
	Interior,

	Cache: Cache_ID,
	bool: IsLoggedIn,
	LoginAttempts,
	LoginTimer
};
new Player[MAX_PLAYERS][E_PLAYERS];

// dialog data
enum
{
	DIALOG_UNUSED,

	DIALOG_LOGIN,
	DIALOG_REGISTER,
	DIALOG_FRIENDS_MENU,
	DIALOG_ADD_FRIEND,
	DIALOG_FRIEND_REQUESTS,
	DIALOG_FRIEND_OPTIONS,
	DIALOG_FRIENDS_LIST,
	DIALOG_FRIENDLIST_OPTIONS,
	DIALOG_POKE_HISTORY
};


/*
	##     ##    ###    ########  ####    ###    ########  ##       ########  ######  
	##     ##   ## ##   ##     ##  ##    ## ##   ##     ## ##       ##       ##    ## 
	##     ##  ##   ##  ##     ##  ##   ##   ##  ##     ## ##       ##       ##       
	##     ## ##     ## ########   ##  ##     ## ########  ##       ######    ######  
 	 ##   ##  ######### ##   ##    ##  ######### ##     ## ##       ##             ## 
  	  ## ##   ##     ## ##    ##   ##  ##     ## ##     ## ##       ##       ##    ## 
   	   ###    ##     ## ##     ## #### ##     ## ########  ######## ########  ######  
*/

// MySQL connection handle
new MySQL: g_SQL;

new FriendRequestSQLID[MAX_PLAYERS][31];
new FriendListSQLID[MAX_PLAYERS][31];
new g_MysqlRaceCheck[MAX_PLAYERS];


main()
{
	print("\n");
	print("  |---------------------------------------------------");
	print("  |--- Friend System by Dragan Avdic (Dragi)");
	print("  |--- Credits: BlueG");
    print("  |--  Script: v0.1");
    print("  |--  20.12.2024.");
	print("  |---------------------------------------------------");
}


/*	DEFAULT CALLBACKS
	########  ######## ########    ###    ##     ## ##       ########     ######  ########  
	##     ## ##       ##         ## ##   ##     ## ##          ##       ##    ## ##     ## 
	##     ## ##       ##        ##   ##  ##     ## ##          ##       ##       ##     ## 
	##     ## ######   ######   ##     ## ##     ## ##          ##       ##       ########  
	##     ## ##       ##       ######### ##     ## ##          ##       ##       ##     ## 
	##     ## ##       ##       ##     ## ##     ## ##          ##       ##    ## ##     ## 
	########  ######## ##       ##     ##  #######  ########    ##        ######  ########  
*/


public OnGameModeInit()
{
	mysqlInit();
	return 1;
}

public OnGameModeExit()
{
	print("Exiting the gamemode, please wait...");

	// save all player data before closing connection
	for (new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
	{
		if (IsPlayerConnected(i))
		{
			// reason is set to 1 for normal 'Quit'
			SSCANF_OnPlayerDisconnect(i, 1);
		}
	}

	mysql_close(g_SQL);
	return 1;
}

public OnPlayerConnect(playerid)
{
	g_MysqlRaceCheck[playerid]++;

	static const empty_player[E_PLAYERS];
	Player[playerid] = empty_player;

	GetPlayerName(playerid, Player[playerid][Name], MAX_PLAYER_NAME);

	new query[103];
	mysql_format(g_SQL, query, sizeof query, "SELECT * FROM `users` WHERE `username` = '%e' LIMIT 1", Player[playerid][Name]);
	mysql_tquery(g_SQL, query, "OnPlayerDataLoaded", "dd", playerid, g_MysqlRaceCheck[playerid]);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	g_MysqlRaceCheck[playerid]++;

	UpdatePlayerData(playerid, reason);

	// if the player was kicked (either wrong password or taking too long) during the login part, remove the data from the memory
	if (cache_is_valid(Player[playerid][Cache_ID]))
	{
		cache_delete(Player[playerid][Cache_ID]);
		Player[playerid][Cache_ID] = MYSQL_INVALID_CACHE;
	}

	// if the player was kicked before the time expires (30 seconds), kill the timer
	if (Player[playerid][LoginTimer])
	{
		KillTimer(Player[playerid][LoginTimer]);
		Player[playerid][LoginTimer] = 0;
	}

	// sets "IsLoggedIn" to false when the player disconnects, it prevents from saving the player data twice when "gmx" is used
	Player[playerid][IsLoggedIn] = false;
	return 1;
}

public OnPlayerSpawn(playerid)
{
	// spawn the player to their last saved position
	SetPlayerInterior(playerid, Player[playerid][Interior]);
	SetPlayerPos(playerid, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos]);
	SetPlayerFacingAngle(playerid, Player[playerid][A_Pos]);

	SetCameraBehindPlayer(playerid);
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	return 1;
}


/*
	########  ####    ###    ##        #######   ######    ######  
	##     ##  ##    ## ##   ##       ##     ## ##    ##  ##    ## 
	##     ##  ##   ##   ##  ##       ##     ## ##        ##       
	##     ##  ##  ##     ## ##       ##     ## ##   ####  ######  
	##     ##  ##  ######### ##       ##     ## ##    ##        ## 
	##     ##  ##  ##     ## ##       ##     ## ##    ##  ##    ## 
	########  #### ##     ## ########  #######   ######    ######  
*/


public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch (dialogid)
	{
		case DIALOG_UNUSED: return 1;

		case DIALOG_LOGIN:
		{
			if (!response) return Kick(playerid);

			bcrypt_verify(playerid, "OnPassswordVerify", inputtext, Player[playerid][Password]);
		}
		case DIALOG_REGISTER:
		{
			if (!response) return Kick(playerid);

			if (strlen(inputtext) <= 5)
			{
				return ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD,
					"Registration",
					"Your password must be longer than 5 characters! \n\
					Please enter your password in the field below:", "Register", "Abort");
			}

			bcrypt_hash(playerid, "OnPassswordRegHash", inputtext, BCRYPT_COST);
		}
		case DIALOG_FRIENDS_MENU:
		{
			if (response)
			{
				switch (listitem)
				{
					case 0: // lista prijatelja
						FetchFriendList(playerid);
					case 1: // dodaj prijatleja
						HandleAddFriend(playerid);
					case 2: // zahtevi za prijateljstvo
						FetchFriendRequests(playerid);
					case 3: // istorija bockanja
						FetchPokeHistory(playerid);
				}
			}
		}
		case DIALOG_ADD_FRIEND:
		{
			if (response)
			{
				new targetid = strval(inputtext);
				new friendCount = CheckFriendCount(targetid);
				new broj;
				
				if (sscanf(inputtext, "i", broj))
				{
					return ShowPlayerDialog(playerid, DIALOG_ADD_FRIEND, DIALOG_STYLE_INPUT, "Dodaj Prijatelja", 
						"Unesite ID igraca kojem saljete zahtev za prijateljstvo:", "Posalji", "Izlaz");
				}

				if (!IsPlayerConnected(targetid) || targetid == playerid)
				{
					SendClientMessage(playerid, -1, "Igrac nije online ili ste uneli nevalidan ID.");
					return 1;
				}
				else if (friendCount > 30)
				{
					SendClientMessage(playerid, -1, "Igrac je ostvario limit sklopljenih prijateljstava.");
					return 1;
				}
				else
				{
					CheckIfFriendExists(playerid, targetid);
				}

				return 1;
			}
		}
		case DIALOG_FRIEND_REQUESTS:
		{
			if (response)
			{
				new targetSQLID = FriendRequestSQLID[playerid][listitem];
				new username[25];

				SetPVarInt(playerid, "SelectedFriendRequest", targetSQLID);

				if (GetUsernameBySQLID(targetSQLID, username, sizeof(username)))
				{
					SetPVarString(playerid, "DFRq_UsernameBySQLID", username);
				}
				else
				{
					printf("Nije pronadjeno korisnicko ime za sqlid: %d, DIALOG_FRIEND_REQUESTS.", targetSQLID);
					return 1;
				}

				ShowPlayerDialog(playerid, DIALOG_FRIEND_OPTIONS, DIALOG_STYLE_LIST, "Prijatelji - Opcije", 
					"Prihvati zahtev za prijateljstvo\nOdbij zahtev za prijateljstvo", "Odaberi", "Odustani");
			}

		}
		case DIALOG_FRIEND_OPTIONS:
		{
			if (response)
			{
				new query[256], targetUsername[25];
				new targetSQLID = GetPVarInt(playerid, "SelectedFriendRequest");

				GetPVarString(playerid, "DFRq_UsernameBySQLID", targetUsername, sizeof(targetUsername));
				DeletePVar(playerid, "SelectedFriendRequest");
				DeletePVar(playerid, "DFRq_UsernameBySQLID");

				switch (listitem)
				{
					case 0: // prihvati zahtev za prijateljstvo
					{
						new Year, Month, Day, date[15];
						new output[80], output2[128];
						new targetID = GetPlayerID(targetUsername);

						getdate(Year, Month, Day);
						format(date, sizeof(date), "%02d/%02d/%d", Day, Month, Year);

						mysql_format(g_SQL, query, sizeof(query), 
							"UPDATE friendships SET status = 'accepted', date = '%s' \
							WHERE user_id = %d AND friend_id = %d AND status = 'pending'", 
							date, targetSQLID, Player[playerid][ID]);

						mysql_tquery(g_SQL, query);

						//printf("Username za sqlid: %d glasi: %s", targetSQLID, targetUsername);

						format(output2, sizeof(output2), "Prihvatili ste zahtev za prijateljstvo od %s.", targetUsername);
						SendClientMessage(playerid, -1, output2);

						if (IsPlayerConnected(targetID))
						{
							format(output, sizeof(output), "%s je prihvatio vas zahtev za prijateljstvo.", ReturnPlayerName(playerid));
							SendClientMessage(targetID, -1, output);
						}
					}
					case 1: // odbij zahtev za prijateljstvo
					{ 
						mysql_format(g_SQL, query, sizeof(query), 
							"UPDATE friendships SET status = 'declined' WHERE user_id = %d AND friend_id = %d AND status = 'pending'", 
							targetSQLID, Player[playerid][ID]);

						mysql_tquery(g_SQL, query);

						SendClientMessage(playerid, -1, "Odbili ste zahtev za prijateljstvo.");
					}
					default: return 1;
				}
			}
		}
		case DIALOG_FRIENDS_LIST:
		{	
			if (response)
			{
				new targetSQLID = FriendListSQLID[playerid][listitem];
				SetPVarInt(playerid, "SelectedFriendList", targetSQLID); 

				ShowPlayerDialog(playerid, DIALOG_FRIENDLIST_OPTIONS, DIALOG_STYLE_LIST, "Prijatelji - Opcije", 
					"Ukloni prijatelja\nBocni prijatelja\nPosalji SMS (Uskoro)", "Odaberi", "Odustani");
			}
		}
		case DIALOG_FRIENDLIST_OPTIONS:
		{
			if (response)
			{
				new targetSQLID = GetPVarInt(playerid, "SelectedFriendList");
				DeletePVar(playerid, "SelectedFriendList");

				switch (listitem)
				{
					case 0: // ukloni prijateljicu
					{
						DeleteFriend(playerid, targetSQLID);
					}
					case 1: // bocni prijatelja
					{
						PokeFriend(playerid, targetSQLID);
					}
					case 2: // posalji SMS prijatelju
					{
						// ovde implementirate vas sistem za slanje posluka prijateljicama!

						SendClientMessage(playerid, -1, "Sistem za slanje poruka prijateljicama je u fazi razvoja.");
					}
					default: return 1;
				}
			}
			return 1;
		}

		default: return 0; // dialog ID was not found, search in other scripts
	}
	return 1;
}


/*
	########  ########     ###    ########    ###       ##     ##    ###    ##    ## ########  ##       
	##     ## ##     ##   ## ##      ##      ## ##      ##     ##   ## ##   ###   ## ##     ## ##       
	##     ## ##     ##  ##   ##     ##     ##   ##     ##     ##  ##   ##  ####  ## ##     ## ##       
	########  ##     ## ##     ##    ##    ##     ##    ######### ##     ## ## ## ## ##     ## ##       
	##        ##     ## #########    ##    #########    ##     ## ######### ##  #### ##     ## ##       
	##        ##     ## ##     ##    ##    ##     ##    ##     ## ##     ## ##   ### ##     ## ##       
	##        ########  ##     ##    ##    ##     ##    ##     ## ##     ## ##    ## ########  ######## 
*/


forward OnPlayerDataLoaded(playerid, race_check);
public OnPlayerDataLoaded(playerid, race_check)
{
	if (race_check != g_MysqlRaceCheck[playerid]) return Kick(playerid);

	new string[115];
	if(cache_num_rows() > 0)
	{
		cache_get_value(0, "password", Player[playerid][Password], 61);

		// saves the active cache in the memory and returns an cache-id to access it for later use
		Player[playerid][Cache_ID] = cache_save();

		format(string, sizeof string, "This account (%s) is registered. Please login by entering your password in the field below:", Player[playerid][Name]);
		ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", string, "Login", "Abort");

		// from now on, the player has 30 seconds to login
		Player[playerid][LoginTimer] = SetTimerEx("OnLoginTimeout", SECONDS_TO_LOGIN * 1000, false, "d", playerid);
	}
	else
	{
		format(string, sizeof string, "Welcome %s, you can register by entering your password in the field below:", Player[playerid][Name]);
		ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Registration", string, "Register", "Abort");
	}
	return 1;
}

forward OnLoginTimeout(playerid);
public OnLoginTimeout(playerid)
{
	// reset the variable that stores the timerid
	Player[playerid][LoginTimer] = 0;

	ShowPlayerDialog(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Login",
		"You have been kicked for taking too long to login successfully to your account.", "Okay", "");
	DelayedKick(playerid);
	return 1;
}

forward OnPlayerRegister(playerid);
public OnPlayerRegister(playerid)
{
	// retrieves the ID generated for an AUTO_INCREMENT column by the sent query
	Player[playerid][ID] = cache_insert_id();

	ShowPlayerDialog(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Registration",
		"Account successfully registered, you have been automatically logged in.", "Okay", "");

	Player[playerid][IsLoggedIn] = true;
	sql_update_players_int(playerid, "isonline", 1);

	Player[playerid][X_Pos] = DEFAULT_POS_X;
	Player[playerid][Y_Pos] = DEFAULT_POS_Y;
	Player[playerid][Z_Pos] = DEFAULT_POS_Z;
	Player[playerid][A_Pos] = DEFAULT_POS_A;

	SetSpawnInfo(playerid, NO_TEAM, 0, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos], Player[playerid][A_Pos], 0, 0, 0, 0, 0, 0);
	SpawnPlayer(playerid);
	return 1;
}

// -----------------------------------------------------------------------------

AssignPlayerData(playerid)
{
	cache_get_value_int(0, "id", Player[playerid][ID]);

	cache_get_value_float(0, "x", Player[playerid][X_Pos]);
	cache_get_value_float(0, "y", Player[playerid][Y_Pos]);
	cache_get_value_float(0, "z", Player[playerid][Z_Pos]);
	cache_get_value_float(0, "angle", Player[playerid][A_Pos]);
	cache_get_value_int(0, "interior", Player[playerid][Interior]);
	return 1;
}

UpdatePlayerData(playerid, reason)
{
	if (Player[playerid][IsLoggedIn] == false) return 0;

	// if the client crashed, it's not possible to get the player's position in OnPlayerDisconnect callback
	// so we will use the last saved position (in case of a player who registered and crashed/kicked, the position will be the default spawn point)
	if (reason == 1)
	{
		GetPlayerPos(playerid, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos]);
		GetPlayerFacingAngle(playerid, Player[playerid][A_Pos]);
	}

	sql_update_players_int(playerid, "isonline", 0);
	new query[145];
	mysql_format(g_SQL, query, sizeof query,
		"UPDATE `users` SET `x` = %f, `y` = %f, `z` = %f, `angle` = %f, `interior` = %d WHERE `id` = %d LIMIT 1",
		Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos], Player[playerid][A_Pos], GetPlayerInterior(playerid), Player[playerid][ID]);
	mysql_tquery(g_SQL, query);
	return 1;
}

// -----------------------------------------------------------------------------
// Bcrypt functions for register and login
// -------

forward OnPassswordRegHash(playerid);
public OnPassswordRegHash(playerid)
{
	new dest[BCRYPT_HASH_LENGTH];
 	bcrypt_get_hash(dest); 
 	//printf("hash : %s", dest);
	Player[playerid][Password][0] = EOS;
 	strmid(Player[playerid][Password], dest, 0, strlen(dest), 61);

	new query[221];
	mysql_format(g_SQL, query, sizeof query,
		"INSERT INTO `users` (`username`, `password`) VALUES ('%e', '%s')",
		Player[playerid][Name], Player[playerid][Password]);
	mysql_tquery(g_SQL, query, "OnPlayerRegister", "d", playerid);

	return 1;
}

forward OnPassswordVerify(playerid, bool:success);
public OnPassswordVerify(playerid, bool:success)
{
 	// success oznacava da li je provera uspesno ili ne

 	if (success)
 	{
		ShowPlayerDialog(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Login",
			"You have been successfully logged in.", "Okay", "");

		// sets the specified cache as the active cache so we can retrieve the rest player data
		cache_set_active(Player[playerid][Cache_ID]);

		AssignPlayerData(playerid);

		// remove the active cache from memory and unsets the active cache as well
		cache_delete(Player[playerid][Cache_ID]);
		Player[playerid][Cache_ID] = MYSQL_INVALID_CACHE;

		KillTimer(Player[playerid][LoginTimer]);
		Player[playerid][LoginTimer] = 0;
		Player[playerid][IsLoggedIn] = true;
		sql_update_players_int(playerid, "isonline", 1);

		// spawn the player to their last saved position after login
		SetSpawnInfo(playerid, NO_TEAM, 0,
			Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos], Player[playerid][A_Pos], 0, 0, 0, 0, 0, 0);
		SpawnPlayer(playerid);
 	}
 	else
 	{
		Player[playerid][LoginAttempts]++;

		if (Player[playerid][LoginAttempts] >= 3)
		{
			ShowPlayerDialog(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Login",
				"You have mistyped your password too often (3 times).", "Okay", "");
			DelayedKick(playerid);
		}
		else 
		{
			ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login",
				"Wrong password!\nPlease enter your password in the field below:", "Login", "Abort");
		}
	}
}


/*
	 ######     ###    ##       ##       ########     ###     ######  ##    ##  ######  
	##    ##   ## ##   ##       ##       ##     ##   ## ##   ##    ## ##   ##  ##    ## 
	##        ##   ##  ##       ##       ##     ##  ##   ##  ##       ##  ##   ##       
	##       ##     ## ##       ##       ########  ##     ## ##       #####     ######  
	##       ######### ##       ##       ##     ## ######### ##       ##  ##         ## 
	##    ## ##     ## ##       ##       ##     ## ##     ## ##    ## ##   ##  ##    ## 
	 ######  ##     ## ######## ######## ########  ##     ##  ######  ##    ##  ######  
*/


forward OnFriendListFetched(playerid);
public OnFriendListFetched(playerid)
{
	new rows = cache_num_rows();

    if (rows > 0) 
    {
		new friendList[2048];

		strdel(friendList, 0, sizeof(friendList));
		strcat(friendList, "Ime\tDatum\tStatus\n");

		for (new i = 0; i < rows; i++)
		{
			new string[128], friendName[25], friendId, is_online;
			new colorString[20], datum[15];

			cache_get_value_name(i, "username", friendName);
			cache_get_value_name(i, "date", datum);
			cache_get_value_name_int(i, "id", friendId);
			cache_get_value_name_int(i, "isonline", is_online);

			colorString = (is_online ? "{00FF00}Online" : "{FF0000}Offline");

			format(string, sizeof(string), "%s\t%s\t%s\n", friendName, datum, colorString);
			FriendListSQLID[playerid][i] = friendId;
			strcat(friendList, string);
		}

    	ShowPlayerDialog(playerid, DIALOG_FRIENDS_LIST, DIALOG_STYLE_TABLIST_HEADERS, "Vasi Prijatelji", friendList, "OK", "Izlaz");
		strdel(friendList, 0, sizeof(friendList));
    }
	else
	{
		SendClientMessage(playerid, -1, "Prijatelje nemate. :(");
	}

	return 1;
}

forward OnFriendRequestsFetched(playerid);
public OnFriendRequestsFetched(playerid)
{
    new rows = cache_num_rows();

    if(rows == 0)
    {
		ShowPlayerDialog(playerid, DIALOG_UNUSED, DIALOG_STYLE_MSGBOX, "Vasi Prijatelji", "Nemate zahteva za prijateljstvo.", "OK", "Izlaz");
    }
	else 
	{
		new requestList[2048];

		strdel(requestList, 0, sizeof(requestList));
		strcat(requestList, "Ime\tDatum\n");

		for (new i = 0; i < rows; i++)
		{
			new requesterName[25], date[15], sqlid, string[128];

			cache_get_value_index_int(i, 0, sqlid);
			cache_get_value_index(i, 1, requesterName);
			cache_get_value_index(i, 2, date);

			format(string, sizeof(string), "%s\t%s\n", requesterName, date);
			FriendRequestSQLID[playerid][i] = sqlid;
			strcat(requestList, string);
		}

		ShowPlayerDialog(playerid, DIALOG_FRIEND_REQUESTS, DIALOG_STYLE_TABLIST_HEADERS,"Zahtevi za Prijateljstvo", requestList, "Izaberi", "Izlaz");
		strdel(requestList, 0, sizeof(requestList));
	}

	return 1;
}

forward CheckIfFriendExists(playerid, targetid);
public CheckIfFriendExists(playerid, targetid)
{
    new query[256];
    new userSQLID = Player[playerid][ID];
    new friendSQLID = Player[targetid][ID];

    mysql_format(g_SQL, query, sizeof(query),
        "SELECT COUNT(*) FROM friendships \
        WHERE (user_id = %d AND friend_id = %d \
        OR user_id = %d AND friend_id = %d) \
        AND (status = 'pending' OR status = 'accepted')",
        userSQLID, friendSQLID, friendSQLID, userSQLID);
    
    mysql_tquery(g_SQL, query, "OnFriendCheckResult", "dd", playerid, targetid);
}

forward OnFriendCheckResult(playerid, targetid);
public OnFriendCheckResult(playerid, targetid)
{
    new count;
    cache_get_value_int(0, 0, count);

    if (count > 0)
    {
        SendClientMessage(playerid, -1, "Prijateljstvo je vec prihvaceno ili je na cekanju.");
    }
	else
	{
		AddFriend(playerid, targetid);
	}

	return 1;
}

forward OnFriendRequestSent(playerid, targetid);
public OnFriendRequestSent(playerid, targetid)
{
	new output1[128], output2[128];
	format(output1, sizeof(output1), "Zahtev za prijateljstvo je poslat: %s.", ReturnPlayerName(targetid));
	format(output2, sizeof(output2), "Imate nov zahtev za prijateljstvo od %s. Pogledajte '/prijatelji'", ReturnPlayerName(playerid));

    SendClientMessage(playerid, -1, output1);
	SendClientMessage(targetid, -1, output2);
	return 1;
}

forward OnPokeHistoryFetched(playerid);
public OnPokeHistoryFetched(playerid)
{
    new rows = cache_num_rows(); 

    if (rows > 0)
    {
        new pokeHistory[2048];
		strdel(pokeHistory, 0, sizeof(pokeHistory));

        for (new i = 0; i < rows; i++)
        {
            new senderName[25], timestamp[32], string[128];

            cache_get_value_index(i, 0, senderName); // Kolona `username`
            cache_get_value_index(i, 1, timestamp); // Kolona `timestamp`

            format(string, sizeof(string), "%s - %s\n", senderName, timestamp);
            strcat(pokeHistory, string);
        }

        ShowPlayerDialog(playerid, DIALOG_POKE_HISTORY, DIALOG_STYLE_MSGBOX, 
            "Istorija bockanja (zadnjih 20)", pokeHistory, "OK", "Izlaz");
    }
    else
    {
        SendClientMessage(playerid, -1, "Niko te jos nije bockao!");
    }

	return 1;
}

forward _KickPlayerDelayed(playerid);
public _KickPlayerDelayed(playerid)
{
	Kick(playerid);
	return 1;
}


/*
########  ##          ###    ##    ## ######## ########     ######## ##     ## ##    ##  ######      
##     ## ##         ## ##    ##  ##  ##       ##     ##    ##       ##     ## ###   ## ##    ##     
##     ## ##        ##   ##    ####   ##       ##     ##    ##       ##     ## ####  ## ##           
########  ##       ##     ##    ##    ######   ########     ######   ##     ## ## ## ## ##           
##        ##       #########    ##    ##       ##   ##      ##       ##     ## ##  #### ##           
##        ##       ##     ##    ##    ##       ##    ##     ##       ##     ## ##   ### ##    ## ### 
##        ######## ##     ##    ##    ######## ##     ##    ##        #######  ##    ##  ######  ### 
 */


 stock GetUsernameBySQLID(targetSQLID, username[], maxlen)
{
	// IMPORTANT NOTE - unthreaded query !!!! nemoj da bi cack'o mecku! nemoj posle Dragi nije rek'o...

    new string[128];
    format(string, sizeof(string), "SELECT username FROM users WHERE id = %d", targetSQLID);

    new Cache:result = mysql_query(g_SQL, string);
    cache_get_value(0, "username", username, maxlen);
    cache_delete(result); // ako ovo ne uradis, sjebao si memoriju celog sistema i posle nema nazad!
    return 1;
}

stock DeleteFriend(playerid, targetSQLID)
{
	new query[256];
	mysql_format(g_SQL, query, sizeof(query), 
		"DELETE FROM friendships \
		WHERE (user_id = %d AND friend_id = %d AND status = 'accepted') \
		OR (user_id = %d AND friend_id = %d AND status = 'accepted')", 
		targetSQLID, Player[playerid][ID], Player[playerid][ID], targetSQLID);

	mysql_tquery(g_SQL, query);

	SendClientMessage(playerid, -1, "Uklonili ste prijateljicu. Imate 1 manje prijatelja dok ne postanete asocijalni.");

	return 1;
}

stock PokeFriend(playerid, targetSQLID)
{
	new username[25];
	if (GetUsernameBySQLID(targetSQLID, username, sizeof(username)))
	{
		new targetID = GetPlayerID(username);
		if(targetID == -1)
		{
			new string[128];
			format(string, sizeof(string), "Prijatelj %s nije pronadjen.", username);
			SendClientMessage(playerid, -1, string);
			return 1;
		}
		else 
		{
			new string[128], string2[128], query[256];
			format(string, sizeof(string), "Prijatelj %s Vas je bocnuo!", Player[playerid][Name]);
			format(string2, sizeof(string2), "Bocnuli ste prijatelja %s.", username);

			mysql_format(g_SQL, query, sizeof(query), 
				"INSERT INTO friend_pokes (sender_id, receiver_id) VALUES (%d, %d)", 
				Player[playerid][ID], targetSQLID);
			mysql_tquery(g_SQL, query);

			SendClientMessage(targetID, -1, string);
			SendClientMessage(playerid, -1, string2);
		}
	}
	else
	{
		printf("Nije pronadjeno korisnicko ime za sqlid: %d, funkcija: PokeFriend.", targetSQLID);
		return 1;
	}

	return 1;
}

stock CheckFriendCount(userid)
{
	// ! IMPORTANT NOTE ! - unthreaded query !!!!

	new string[256];
    format(string, sizeof(string),
		"SELECT COUNT(*) FROM friendships WHERE (user_id = %d OR friend_id = %d) AND status = 'accepted'",
		Player[userid][ID], Player[userid][ID]);

    new friend_count, Cache:result = mysql_query(g_SQL, string);
	cache_get_value_int(0, 0, friend_count);
    cache_delete(result);
	//printf("friend counts: %d, sqlid: %d", friend_count, Player[userid][ID]);
	return friend_count;
}

stock AddFriend(playerid, targetid)
{ 
    new query[256];
	new Year, Month, Day, date[15];
	getdate(Year, Month, Day);
	format(date, sizeof(date), "%02d/%02d/%d", Day, Month, Year);

    mysql_format(g_SQL, query, sizeof(query), 
        "INSERT INTO friendships (user_id, friend_id, status, date) VALUES (%d, %d, 'pending', '%s')",
        Player[playerid][ID], Player[targetid][ID], date);
    
    mysql_tquery(g_SQL, query, "OnFriendRequestSent", "dd", playerid, targetid);
}

// -----------------------------------------------------------------------------
// DIALOG_FRIENDS_MENU functions
// -------

stock FetchFriendList(playerid)
{
    new query[512];
    mysql_format(g_SQL, query, sizeof(query), 
        "SELECT u.id, u.username, u.isonline, f.date FROM friendships f \
        JOIN users u ON (u.id = f.friend_id AND f.user_id = %d) \
        OR (u.id = f.user_id AND f.friend_id = %d) \
        WHERE f.status = 'accepted'", 
        Player[playerid][ID], Player[playerid][ID]);

    mysql_tquery(g_SQL, query, "OnFriendListFetched", "i", playerid);
}

stock HandleAddFriend(playerid)
{
    new friendCount = CheckFriendCount(playerid);
    if (friendCount > 30)
    {
        SendClientMessage(playerid, -1, "Ne mozete imati vise od 30 prijatelja.");
    }
    else 
    {
        ShowPlayerDialog(playerid, DIALOG_ADD_FRIEND, DIALOG_STYLE_INPUT, "Dodaj prijatelja", 
            "Unesite ID igraca kojem zelite poslati zahtev za prijateljstvo:", "Posalji", "Odustani");
    }
}

stock FetchFriendRequests(playerid)
{
    new query[512];
    mysql_format(g_SQL, query, sizeof(query), 
        "SELECT users.id, users.username, friendships.date \
        FROM friendships JOIN users ON users.id = friendships.user_id \
        WHERE friendships.friend_id = %d AND friendships.status = 'pending'", 
        Player[playerid][ID]);

    mysql_tquery(g_SQL, query, "OnFriendRequestsFetched", "i", playerid);
}

stock FetchPokeHistory(playerid)
{
    new query[256];
    mysql_format(g_SQL, query, sizeof(query), 
        "SELECT u.username, p.timestamp FROM friend_pokes p \
        JOIN users u ON u.id = p.sender_id \
        WHERE p.receiver_id = %d \
        ORDER BY p.timestamp DESC \
        LIMIT 20", Player[playerid][ID]);
    
    mysql_tquery(g_SQL, query, "OnPokeHistoryFetched", "i", playerid);
}

DelayedKick(playerid, time = 500)
{
	SetTimerEx("_KickPlayerDelayed", time, false, "d", playerid);
	return 1;
}


/*
########  ########     ##     ##    ###    ##    ## ########  ##       ######## ########  
##     ## ##     ##    ##     ##   ## ##   ###   ## ##     ## ##       ##       ##     ## 
##     ## ##     ##    ##     ##  ##   ##  ####  ## ##     ## ##       ##       ##     ## 
##     ## ########     ######### ##     ## ## ## ## ##     ## ##       ######   ########  
##     ## ##     ##    ##     ## ######### ##  #### ##     ## ##       ##       ##   ##   
##     ## ##     ##    ##     ## ##     ## ##   ### ##     ## ##       ##       ##    ##  
########  ########     ##     ## ##     ## ##    ## ########  ######## ######## ##     ## 
*/

mysqlInit()
{
	new MySQLOpt: option_id = mysql_init_options();

	mysql_set_option(option_id, AUTO_RECONNECT, true); 

	g_SQL = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE, option_id);
	if (g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
	{
		print("MySQL connection failed. Server is shutting down.");
		SendRconCommand("exit"); 
		return 1;
	}

	print("MySQL connection is successful.");
	return 1;
}


/* PLAYER SQL FUNCTIONS
########       ######   #######  ##          ######## ##     ## ##    ##  ######  
##     ##     ##    ## ##     ## ##          ##       ##     ## ###   ## ##    ## 
##     ##     ##       ##     ## ##          ##       ##     ## ####  ## ##       
########       ######  ##     ## ##          ######   ##     ## ## ## ## ##       
##                  ## ##  ## ## ##          ##       ##     ## ##  #### ##       
##        ### ##    ## ##    ##  ##          ##       ##     ## ##   ### ##    ## 
##        ###  ######   ##### ## ########    ##        #######  ##    ##  ######  
*/


sql_update_players_int(playerid, const column_name[], value)
{
	new query[128];
	mysql_format(g_SQL, query, sizeof(query),
				"UPDATE `users` SET `%s` = '%d' WHERE `id` = '%d' LIMIT 1", column_name, value, Player[playerid][ID]);
    mysql_tquery(g_SQL, query);

	return 1;
}


/*
	 ######   #######  ##     ## ##     ##    ###    ##    ## ########   ######  
	##    ## ##     ## ###   ### ###   ###   ## ##   ###   ## ##     ## ##    ## 
	##       ##     ## #### #### #### ####  ##   ##  ####  ## ##     ## ##       
	##       ##     ## ## ### ## ## ### ## ##     ## ## ## ## ##     ##  ######  
	##       ##     ## ##     ## ##     ## ######### ##  #### ##     ##       ## 
	##    ## ##     ## ##     ## ##     ## ##     ## ##   ### ##     ## ##    ## 
	 ######   #######  ##     ## ##     ## ##     ## ##    ## ########   ######  
 */


CMD:prijatelji(playerid)
{
	// ! IMPORTANT NOTE ! - unthreaded query !!!! nemoj da bi cack'o mecku! ok?

    new string[128];
    format(string, sizeof(string), "SELECT COUNT(*) FROM friendships WHERE friend_id = %d AND status = 'pending'", Player[playerid][ID]);
    new friend_requests, Cache:result = mysql_query(g_SQL, string);
	cache_get_value_int(0, 0, friend_requests);
    cache_delete(result); // ako ovo ne uradis, sjebao si memoriju celog sistema i posle nema nazad!
	//////////////////////////////////////////////////////////////////
	
	new menu_text[150];
	format(menu_text, sizeof(menu_text), "Lista prijatelja\n\
         Dodaj prijatelja\n\
         Zahtevi za prijateljstvo (%d)\n\
         Istorija bockanja", friend_requests);

    ShowPlayerDialog(playerid, DIALOG_FRIENDS_MENU, DIALOG_STYLE_LIST, "Meni Prijatelja", menu_text, "Izaberi", "Izlaz");
    return 1;
}

#endinput