#include <a_samp>
#include <a_mysql>
#include <sscanf2>
#include <zcmd>
#include <foreach>
#include <crashdetect>

main() {}

new 
	mysqlString[256],
	formatString[256];

#define format_mysql( 			mysqlString[0] = EOS; mysql_format(dbHandle, mysqlString, sizeof mysqlString,
#define format_string( 			formatString[0] = EOS; format(formatString, sizeof formatString,

#define GetName(%0)				pInfo[%0][pName]

new dbHandle;
static const
	MYSQL_HOST[] = !"localhost",
	MYSQL_USER[] = !"root",
	MYSQL_PASSWORD[] = !"",
	MYSQL_DB[] = !"test";

enum playerData
{
	pName[MAX_PLAYER_NAME],
	pOrganization,
	pOrgRank,
	pOfferPlayer,
	pCurrentListitem
};
new pInfo[MAX_PLAYERS][playerData];

#define MAX_ORGANIZATIONS	1000
#define MAX_RANKS			8
enum organizationData
{
	orgID,
	orgName[64],
	orgLeader[MAX_PLAYER_NAME]
};
new orgInfo[MAX_ORGANIZATIONS][organizationData];
new orgRanks[MAX_ORGANIZATIONS][MAX_RANKS][64];

enum dialogIDs
{
	dCreateOrg,
	dLeaveOrg,
	dInviteOrg,
	dPanelOrg,
	dChangeNameOrg,
	dInvitePlayerOrg,
	dChangeRanksOrg,
	dChangeRanksInputOrg,
	dSetRankOrg,
	dUninviteOrg,
	dOffUninviteOrg,
	dDisbandOrg
};


//
// Callbacks
//

public OnPlayerConnect(playerid)
{
	new playerName[MAX_PLAYER_NAME];
	GetPlayerName(playerid, playerName, MAX_PLAYER_NAME);
	SetString(GetName(playerid), playerName);

	ClearPlayerData(playerid);

 	return 1;
}

public OnPlayerSpawn(playerid)
{
	if(IsPlayerNPC(playerid)) 
		return 1;

	SetPlayerPos(playerid, 1176.8413,-1324.0846,14.0412);

	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	format_mysql("SELECT * FROM `accounts` WHERE name = '%s'", GetName(playerid));
	mysql_tquery(dbHandle, mysqlString, !"@LoadPlayerData", !"i", playerid);

	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	if(IsPlayerNPC(playerid)) 
		return 1;

	return 0;
}

public OnGameModeInit()
{
	SetGameModeText(!"github.com/sfs13");

	ShowPlayerMarkers(PLAYER_MARKERS_MODE_GLOBAL);
	ShowNameTags(1);
	SetNameTagDrawDistance(40.0);
	EnableStuntBonusForAll(0);
	DisableInteriorEnterExits();

	SetWeather(2);
	SetWorldTime(11);

	dbHandle = mysql_connect(MYSQL_HOST, MYSQL_USER, MYSQL_DB, MYSQL_PASSWORD);
	mysql_log(LOG_WARNING | LOG_ERROR);

	mysql_tquery(dbHandle, !"SET CHARACTER SET 'utf8'", "", "");
	mysql_tquery(dbHandle, !"SET NAMES 'utf8'", "", "");
	mysql_tquery(dbHandle, !"SET character_set_client = 'cp1251'", "", "");
	mysql_tquery(dbHandle, !"SET character_set_connection = 'cp1251'", "", "");
	mysql_tquery(dbHandle, !"SET character_set_results = 'cp1251'", "", "");
	mysql_tquery(dbHandle, !"SET SESSION collation_connection = 'utf8_general_ci'", "", "");

	mysql_tquery(dbHandle, !"SELECT * FROM `organizations`", "@LoadOrganizations", "");

	return 1;
}

public OnPlayerUpdate(playerid)
{
	if(!IsPlayerConnected(playerid)) 
		return 0;

	if(IsPlayerNPC(playerid)) 
		return 1;

	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch(dialogid)
	{
		case dCreateOrg:
		{
			if(!response)
				return 1;
			
			new 
				inputName[64];

			if(sscanf(inputtext, "s[64]", inputName) || strlen(inputtext) > 64)
				return ShowPlayerDialog(playerid, dCreateOrg, DIALOG_STYLE_INPUT, !"Создание организации", !"{FFFFFF}Введите название организации (макс. длина - 64 символа):", !"Далее", !"Отмена");

			format_mysql("INSERT INTO `organizations` (`name`, `leader`) VALUES ('%s', '%s')", inputName, GetName(playerid));
			mysql_tquery(dbHandle, mysqlString, !"@CreateOrganization", !"is", playerid, inputName);

			format_string("Вы успешно создали организацию '%s'", inputName);
			SendClientMessage(playerid, 0x00FF00FF, formatString);
		}
		case dLeaveOrg:
		{
			if(!response)
				return 1;

			new
				org = pInfo[playerid][pOrganization];

			if(GetString(orgInfo[org][orgLeader], GetName(playerid)))
			{
				format_mysql("DELETE FROM `organizations` WHERE `id` = %d", org);
				mysql_tquery(dbHandle, mysqlString, "", "");

				format_mysql("UPDATE `accounts` SET `organization` = 0 WHERE `organization` = %d", org);
				mysql_tquery(dbHandle, mysqlString, "", "");

				foreach(new i : Player)
				{
					if(pInfo[i][pOrganization] == org)
					{
						pInfo[i][pOrganization] =
						pInfo[i][pOrgRank] = 0;

						SaveAccount(i);

						if(i != playerid)
							SendClientMessage(i, 0xFF0000FF, !"[O] Ваша организация была распущена лидером");
					}
				}

				SendClientMessage(playerid, 0xFF0000FF, !"Вы покинули организацию, тем самым распустив её");

				ClearOrganization(org);
			}
			else
			{
				pInfo[playerid][pOrganization] =
				pInfo[playerid][pOrgRank] = 0;

				SendClientMessage(playerid, 0xFF0000FF, !"Вы покинули организацию");
			}

			SaveAccount(playerid);
		}
		
		case dInviteOrg:
		{
			if(!response)
			{
				format_string("%s отказался от предложения вступить в Вашу организацию", GetName(playerid));
				SendClientMessage(pInfo[playerid][pOfferPlayer], 0xFF0000FF, formatString);
			}
			else
			{
				new
					targetid = pInfo[playerid][pOfferPlayer],
					org = pInfo[targetid][pOrganization];
				
				pInfo[playerid][pOrganization] = org;
				pInfo[playerid][pOrgRank] = 1;

				SendClientMessage(playerid, 0x00FF00FF, "Вы приняли предложение вступить в организацию");

				format_string("%s принял предложение вступить в Вашу организацию", GetName(playerid));
				SendClientMessage(pInfo[playerid][pOfferPlayer], 0x00FF00FF, formatString);

				foreach(new i : Player)
				{
					if(pInfo[i][pOrganization] == org)
					{
						format_string("[O] %s вступил в организацию", GetName(playerid));
						SendClientMessage(i, 0xFFFF00FF, formatString);
					}
				}

				SaveAccount(playerid);
			}

			pInfo[playerid][pOfferPlayer] = INVALID_PLAYER_ID;
		}

		case dPanelOrg:
		{
			if(!response)
				return 1;
			
			switch(listitem)
			{
				case 0:
					cmd_orgonline(playerid);
				case 1:
					ShowPlayerDialog(playerid, dChangeNameOrg, DIALOG_STYLE_INPUT, !"Смена название", !"{FFFFFF}Введите новое название для организации:", !"Далее", !"Отмена");
				case 2:
					ShowPlayerDialog(playerid, dInvitePlayerOrg, DIALOG_STYLE_INPUT, !"Пригласить игрока", !"{FFFFFF}Введите ID игрока, которого Вы хотите пригласить:", !"Далее", !"Отмена");
				case 3:
				{
					new
						ranks[512],
						currentRank[64];
					
					for(new i = 0; i < MAX_RANKS; i++)
					{
						currentRank[0] = EOS;

						if(i != MAX_RANKS - 1)
							format(currentRank, sizeof currentRank, "%d. %s\n", i + 1, orgRanks[pInfo[playerid][pOrganization]][i]);
						else
							format(currentRank, sizeof currentRank, "%d. %s", i + 1, orgRanks[pInfo[playerid][pOrganization]][i]);
						
						strcat(ranks, currentRank);
					}

					ShowPlayerDialog(playerid, dChangeRanksOrg, DIALOG_STYLE_LIST, !"Выберите ранг", ranks, !"Далее", !"Отмена");
				}
				case 4:
					ShowPlayerDialog(playerid, dSetRankOrg, DIALOG_STYLE_INPUT, !"Изменить ранг игроку", !"{FFFFFF}Введите ID игрока и ранг через запятую\n\n{AFAFAF}Например: 34,2", !"Далее", !"Отмена");
				case 5:
					ShowPlayerDialog(playerid, dUninviteOrg, DIALOG_STYLE_INPUT, !"Выгнать игрока Online", !"{FFFFFF}Введите ID игрока, которого Вы хотите выгнать:", !"Далее", !"Отмена");
				case 6:
					ShowPlayerDialog(playerid, dOffUninviteOrg, DIALOG_STYLE_INPUT, !"Выгнать игрока Offline", !"{FFFFFF}Введите ник игрока, которого Вы хотите выгнать в Offline:", !"Далее", !"Отмена");
				case 7:
					ShowPlayerDialog(playerid, dDisbandOrg, DIALOG_STYLE_MSGBOX, !"Распустить организацию", !"{FFFFFF}Вы уверены, что хотите распустить организацию?", !"Да", !"Отмена");
			}
		}

		case dChangeNameOrg:
		{
			if(!response)
				return cmd_orgpanel(playerid);
			
			new 
				inputName[64],
				org = pInfo[playerid][pOrganization];

			if(sscanf(inputtext, "s[64]", inputName) || strlen(inputName) > 64)
			{
				ShowPlayerDialog(playerid, dChangeNameOrg, DIALOG_STYLE_INPUT, !"Смена название", !"{FFFFFF}Введите новое название для организации:", !"Далее", !"Отмена");
				return SendClientMessage(playerid, 0xFF0000FF, !"Введите корректное название (макс. длина - 64 символа)");
			}

			SetString(orgInfo[org][orgName], inputName);

			format_string("Вы успешно сменили название на '%s'", inputName);
			SendClientMessage(playerid, 0x00FF00FF, formatString);

			SaveOrganization(org);
		}

		case dInvitePlayerOrg:
		{
			if(!response)
				return cmd_orgpanel(playerid);
			
			new
				targetid;

			if(sscanf(inputtext, "d", targetid))
				return ShowPlayerDialog(playerid, dInvitePlayerOrg, DIALOG_STYLE_INPUT, !"Пригласить игрока", !"{FFFFFF}Введите ID игрока, которого Вы хотите пригласить:", !"Далее", !"Отмена");

			cmd_orginvite(playerid, inputtext);
		}

		case dChangeRanksOrg:
		{
			if(!response)
				return cmd_orgpanel(playerid);

			pInfo[playerid][pCurrentListitem] = listitem;

			ShowPlayerDialog(playerid, dChangeRanksInputOrg, DIALOG_STYLE_INPUT, !"Название ранга", !"{FFFFFF}Введите новое название для данного ранга (макс. длина - 64 символа):", !"Далее", !"Отмена");
		}

		case dChangeRanksInputOrg:
		{
			if(!response)
			{
				new
					ranks[512],
					currentRank[64];

				for(new i = 0; i < MAX_RANKS; i++)
				{
					currentRank[0] = EOS;

					if(i != MAX_RANKS - 1)
						format(currentRank, sizeof currentRank, "%d. %s\n", i + 1, orgRanks[pInfo[playerid][pOrganization]][i]);
					else
						format(currentRank, sizeof currentRank, "%d. %s", i + 1, orgRanks[pInfo[playerid][pOrganization]][i]);

					strcat(ranks, currentRank);
				}

				return ShowPlayerDialog(playerid, dChangeRanksOrg, DIALOG_STYLE_LIST, !"Выберите ранг", ranks, !"Далее", !"Отмена");
			}

			new
				rankName[64],
				org = pInfo[playerid][pOrganization],
				currentListitem = pInfo[playerid][pCurrentListitem];

			if(sscanf(inputtext, "s[64]", rankName) || strlen(rankName) > 64)
				return ShowPlayerDialog(playerid, dChangeRanksInputOrg, DIALOG_STYLE_INPUT, !"Название ранга", !"{FFFFFF}Введите новое название для данного ранга (макс. длина - 64 символа):", !"Далее", !"Отмена");

			format_string("Вы сменили название ранга '%s' на '%s'", orgRanks[org][currentListitem], rankName);
			SendClientMessage(playerid, 0x00FF00FF, formatString);

			SetString(orgRanks[org][currentListitem], rankName);
			SaveOrganization(org);
		}

		case dSetRankOrg:
		{
			if(!response)
				return cmd_orgpanel(playerid);
			
			new
				targetid,
				rank;
			
			if(sscanf(inputtext, "p<,>dd", targetid, rank))
				return ShowPlayerDialog(playerid, dSetRankOrg, DIALOG_STYLE_INPUT, !"Изменить ранг игроку", !"{FFFFFF}Введите ID игрока и ранг через запятую\n\n{AFAFAF}Например: 34,2", !"Далее", !"Отмена");
		
			cmd_orgsetrank(playerid, inputtext);
		}

		case dUninviteOrg:
		{
			if(!response)
				return cmd_orgpanel(playerid);
			
			new
				targetid;

			if(sscanf(inputtext, "d", targetid))
				return ShowPlayerDialog(playerid, dUninviteOrg, DIALOG_STYLE_INPUT, !"Выгнать игрока Online", !"{FFFFFF}Введите ID игрока, которого Вы хотите выгнать:", !"Далее", !"Отмена");
			
			cmd_orguninvite(playerid, inputtext);
		}

		case dOffUninviteOrg:
		{
			if(!response)
				return cmd_orgpanel(playerid);
			
			new
				offUninviteStr[MAX_PLAYER_NAME];

			if(sscanf(inputtext, "s[64]", offUninviteStr))
				return ShowPlayerDialog(playerid, dOffUninviteOrg, DIALOG_STYLE_INPUT, !"Выгнать игрока Offline", !"{FFFFFF}Введите ник игрока, которого Вы хотите выгнать в Offline:", !"Далее", !"Отмена");
			
			cmd_orgoffuninvite(playerid, offUninviteStr);
		}

		case dDisbandOrg:
		{
			if(!response)
				return cmd_orgpanel(playerid);

			new
				org = pInfo[playerid][pOrganization];

			format_mysql("DELETE FROM `organizations` WHERE `id` = %d", org);
			mysql_tquery(dbHandle, mysqlString, "", "");

			format_mysql("UPDATE `accounts` SET `organization` = 0 WHERE `organization` = %d", org);
			mysql_tquery(dbHandle, mysqlString, "", "");

			foreach(new i : Player)
			{
				if(pInfo[i][pOrganization] == org)
				{
					pInfo[i][pOrganization] =
					pInfo[i][pOrgRank] = 0;

					SaveAccount(i);
					
					if(i != playerid)
						SendClientMessage(i, 0xFF0000FF, !"[O] Ваша организация была распущена лидером");
				}
			}

			SendClientMessage(playerid, 0xFF0000FF, !"Вы распустили организацию");

			ClearOrganization(org);
		}
	}

	return 1;
}


//
// Commands
//

CMD:orgcreate(playerid, params[])
{
	if(pInfo[playerid][pOrganization] != 0)
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы уже состоите в организации");

	ShowPlayerDialog(playerid, dCreateOrg, DIALOG_STYLE_INPUT, !"Создание организации", !"{FFFFFF}Введите название организации (макс. длина - 64 символа):", !"Далее", !"Отмена");

	return 1;
}

CMD:orgleave(playerid)
{
	new
		org = pInfo[playerid][pOrganization];
	
	if(!org)
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы не состоите в организации");
	
	ShowPlayerDialog(playerid, dLeaveOrg, DIALOG_STYLE_MSGBOX, !"Покинуть организцаию", 
		(GetString(orgInfo[org][orgLeader], GetName(playerid))) ?
		(!"{FFFFFF}Вы являетесь лидером организации. Если Вы покинете её, она будет распущена.") :
		(!"{FFFFFF}Вы действительно хотите покинуть организацию?"),
	!"Далее", !"Отмена");

	return 1;
}

CMD:orginvite(playerid, params[])
{
	new
		org = pInfo[playerid][pOrganization];

	if(!org)
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы не состоите в организации");

	else if(pInfo[playerid][pOrgRank] < MAX_RANKS - 1)
		return SendClientMessage(playerid, 0xFF0000FF, !"У Вас недостаточно высокий ранг");

	else if(sscanf(params, "d", params[0]))
		return SendClientMessage(playerid, -1, !"Введите: /orginvite [id игрока]");

	else if(params[0] == playerid)
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы указали свой ID");

	else if(!IsValidID(playerid))
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы указали неверный ID");
	
	new
		Float:X,
		Float:Y,
		Float:Z;

	GetPlayerPos(params[0], X, Y, Z);
	if(GetPlayerDistanceFromPoint(playerid, X, Y, Z) > 10.0)
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы должны находиться рядом с игроком");

	else if(pInfo[params[0]][pOrganization] != 0)
		return SendClientMessage(playerid, 0xFF0000FF, !"Игрок уже состоит в организации");
	
	format_string("Вы предложили %s присоединиться к Вашей организации", GetName(params[0]));
	SendClientMessage(playerid, 0x00FF00FF, formatString);

	format_string("{FFFFFF}%s предложил Вам присоединиться к организации\n{FFFF00}'%s'\n{FFFFFF}Вы согласны?", GetName(playerid), orgInfo[org][orgName]);
	ShowPlayerDialog(params[0], dInviteOrg, DIALOG_STYLE_MSGBOX, !"Вступить в организацию", formatString, !"Да", !"Отмена");

	pInfo[params[0]][pOfferPlayer] = playerid;

	return 1;
}

CMD:orguninvite(playerid, params[])
{
	new
		org = pInfo[playerid][pOrganization];

	if(!org)
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы не состоите в организации");

	else if(pInfo[playerid][pOrgRank] < MAX_RANKS - 1)
		return SendClientMessage(playerid, 0xFF0000FF, !"У Вас недостаточно высокий ранг");

	else if(sscanf(params, "d", params[0]))
		return SendClientMessage(playerid, -1, !"Введите: /orguninvite [id игрока]");

	else if(params[0] == playerid)
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы указали свой ID");

	else if(!IsValidID(playerid))
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы указали неверный ID");

	else if(pInfo[params[0]][pOrganization] != org)
		return SendClientMessage(playerid, 0xFF0000FF, !"Игрок не состоит в Вашей организации");
	
	else if(pInfo[params[0]][pOrgRank] >= pInfo[playerid][pOrgRank])
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы не можете выгнать этого игрока");
	
	format_string("Вы выгнали %s из организации", GetName(params[0]));
	SendClientMessage(playerid, 0xFF0000FF, formatString);

	format_string("%s выгнал Вас из организации", GetName(playerid));
	SendClientMessage(params[0], 0xFF0000FF, formatString);

	pInfo[params[0]][pOrganization] =
	pInfo[params[0]][pOrgRank] = 0;

	SaveAccount(params[0]);

	return 1;
}

CMD:orgoffuninvite(playerid, params[])
{
	new
		org = pInfo[playerid][pOrganization],
		name[32];

	if(!org)
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы не состоите в организации");

	else if(pInfo[playerid][pOrgRank] < MAX_RANKS - 1)
		return SendClientMessage(playerid, 0xFF0000FF, !"У Вас недостаточно высокий ранг");

	else if(sscanf(params, "s[32]", name))
		return SendClientMessage(playerid, -1, !"Введите: /orgoffuninvite [ник игрока]");

	else if(GetPlayerID(name) != INVALID_PLAYER_ID)
		return SendClientMessage(playerid, 0xFF0000FF, !"Игрок в сети. Используйте команду /orguninvite");

	format_mysql("SELECT `org_rank` FROM `accounts` WHERE name = '%s' AND organization = %d", name, org);
	mysql_tquery(dbHandle, mysqlString, "@OrgOffUninvite", "is", playerid, name);

	return 1;
}

CMD:orgonline(playerid)
{
	new
		org = pInfo[playerid][pOrganization],
		num = 0;

	if(!org)
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы не состоите в организации");

	SendClientMessage(playerid, 0xFFFF00FF, !"Члены организации в сети:");

	foreach(new i : Player)
	{
		if(pInfo[i][pOrganization] == org)
		{
			format_string("%s[%d] | %s (%d)", GetName(i), i, orgRanks[org][pInfo[i][pOrgRank] - 1], pInfo[i][pOrgRank]);
			SendClientMessage(playerid, 0xFFFF00FF, formatString);

			num++;
		}
	}

	format_string("Всего: %d человек(-а)", num);
	SendClientMessage(playerid, 0xFFFF00FF, formatString);

	return 1;
}

CMD:orgchat(playerid, params[])
{
	new
		org = pInfo[playerid][pOrganization],
		text[128];
	
	if(!org)
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы не состоите в организации");

	if(sscanf(params, "s[128]", text))
		return SendClientMessage(playerid, -1, !"Введите: /orgchat [сообщение]");
	
	foreach(new i : Player)
	{
		if(pInfo[i][pOrganization] == org)
		{
			format_string("[O] %s %s[%d]: %s", orgRanks[org][pInfo[playerid][pOrgRank] - 1], GetName(playerid), playerid, text);
			SendClientMessage(i, 0xFFFF00FF, formatString);
		}
	}
	
	return 1;
}

CMD:orgsetrank(playerid, params[])
{
	new
		org = pInfo[playerid][pOrganization];

	if(!org)
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы не состоите в организации");

	else if(pInfo[playerid][pOrgRank] < MAX_RANKS - 1)
		return SendClientMessage(playerid, 0xFF0000FF, !"У Вас недостаточно высокий ранг");

	else if(sscanf(params, "dd", params[0], params[1]) || !(1 < params[1] < MAX_RANKS))
		return SendClientMessage(playerid, -1, !"Введите: /orgsetrank [id игрока] [ранг]");

	else if(params[0] == playerid)
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы указали свой ID");

	else if(!IsValidID(playerid))
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы указали неверный ID");

	else if(pInfo[params[0]][pOrganization] != org)
		return SendClientMessage(playerid, 0xFF0000FF, !"Игрок не состоит в Вашей организации");
	
	else if(params[1] >= pInfo[playerid][pOrgRank])
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы не можете выдать этот ранг");
	
	else if(pInfo[params[0]][pOrgRank] >= pInfo[playerid][pOrgRank])
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы не можете изменять ранг этого игрока");
	
	pInfo[params[0]][pOrgRank] = params[1];

	format_string("Вы выдали %s %d ранг", GetName(params[0]), params[1]);
	SendClientMessage(playerid, 0xFFFF00FF, formatString);

	format_string("%s выдал Вам %d ранг", GetName(playerid), params[1]);
	SendClientMessage(params[0], 0xFFFF00FF, formatString);

	SaveAccount(params[0]);

	return 1;
}

CMD:orgpanel(playerid)
{
	if(!pInfo[playerid][pOrganization])
		return SendClientMessage(playerid, 0xFF0000FF, !"Вы не состоите в организации");

	else if(pInfo[playerid][pOrgRank] < MAX_RANKS - 1)
		return SendClientMessage(playerid, 0xFF0000FF, !"У Вас недостаточно высокий ранг");
	
	ShowPlayerDialog(playerid, dPanelOrg, DIALOG_STYLE_LIST, !"Управление организацией", !"\
				1. Члены организации в сети\n\
				2. Сменить название организации\n\
				3. Пригласить игрока\n\
				4. Изменить название рангов\n\
				5. Изменить ранг игрока\n\
				6. Выгнать игрока {00FF00}Online{FFFFFF}\n\
				7. Выгнать игрока {FF0000}Offline{FFFFFF}\n\
				8. Распустить организацию", !"Далее", !"Отмена");

	return 1;
}


//
// Functions
//

stock SetString(param_1[], const param_2[], size = 300) 
	return strmid(param_1, param_2, 0, strlen(param_2), size);

stock GetString(const param1[], const param2[]) 
	return !strcmp(param1, param2, false);

stock GetPlayerID(const name[])
{
	foreach(new i : Player)
	{
		if(GetString(GetName(i), name))
			return i;
	}

	return INVALID_PLAYER_ID;
}

stock ClearPlayerData(playerid)
{
	pInfo[playerid][pCurrentListitem] = -1;

	pInfo[playerid][pOfferPlayer] 	= INVALID_PLAYER_ID;

	pInfo[playerid][pOrganization] 	=
	pInfo[playerid][pOrgRank] 		= 0;
}

stock SaveAccount(playerid)
{
	format_mysql("UPDATE `accounts` SET \
				`organization` = %d, \
				`org_rank` = %d \
				WHERE `name` = '%s'",
				pInfo[playerid][pOrganization],
				pInfo[playerid][pOrgRank],
				GetName(playerid));
	mysql_tquery(dbHandle, mysqlString, "", "");
}

stock IsValidID(playerid)
{
	if(playerid == INVALID_PLAYER_ID ||
		!IsPlayerConnected(playerid) ||
		IsPlayerNPC(playerid))
			return 0;
	
	return 1;
}

stock ClearOrganization(org)
{
	orgInfo[org][orgID] = -1;
	SetString(orgInfo[org][orgName], !"None");
	SetString(orgInfo[org][orgLeader], !"None");

	for(new i = 0; i < MAX_RANKS; i++)
		SetString(orgRanks[org][i], !"None");
}

stock SaveOrganization(org)
{
	new
		ranks[512],
		rankName[64];
	
	for(new i = 0; i < MAX_RANKS; i++)
	{
		rankName[0] = EOS;

		format(rankName, sizeof rankName, (i != MAX_RANKS - 1) ? "%s|" : "%s", orgRanks[org][i]);
		strcat(ranks, rankName);
	}
	
	format_mysql("UPDATE `organizations` SET \
				`name` = '%s', \
				`leader` = '%s', \
				`ranks` = '%s' \
				WHERE `id` = %d",
				orgInfo[org][orgName],
				orgInfo[org][orgLeader],
				ranks,
				org);
	mysql_tquery(dbHandle, mysqlString, "", "");
}


//
// Publics
//

@LoadPlayerData(playerid);
@LoadPlayerData(playerid)
{
	new rows, fields;
 	cache_get_data(rows, fields);

	if(!rows) 
	{
		format_mysql("INSERT INTO `accounts` (`name`, `organization`) VALUES ('%s', 0)", GetName(playerid));
		mysql_tquery(dbHandle, mysqlString, "", "");
	} 
	else 
	{
		pInfo[playerid][pOrganization] = cache_get_row_int(0, 1, dbHandle);
		pInfo[playerid][pOrgRank] = cache_get_row_int(0, 2, dbHandle);
	}

	SpawnPlayer(playerid);

	return 1;
}

@LoadOrganizations();
@LoadOrganizations()
{
	new rows, fields;
 	cache_get_data(rows, fields);

	if(rows)
	{
		new
			currentOrg;

		for(new i = 0; i < rows; i++)
		{
			currentOrg = cache_get_row_int(i, 0, dbHandle);

			orgInfo[currentOrg][orgID] = currentOrg;
			cache_get_row(i, 1, orgInfo[currentOrg][orgName], dbHandle, 64);
			cache_get_row(i, 2, orgInfo[currentOrg][orgLeader], dbHandle, MAX_PLAYER_NAME);

			new
				ranks[512];
			cache_get_row(i, 3, ranks, dbHandle, sizeof ranks);
			sscanf(ranks, "p<|>s[64]s[64]s[64]s[64]s[64]s[64]s[64]s[64]", 
						orgRanks[currentOrg][0],
						orgRanks[currentOrg][1],
						orgRanks[currentOrg][2],
						orgRanks[currentOrg][3],
						orgRanks[currentOrg][4],
						orgRanks[currentOrg][5],
						orgRanks[currentOrg][6],
						orgRanks[currentOrg][7]);
		}
	}

	return 1;
}

@CreateOrganization(playerid, const inputName[]);
@CreateOrganization(playerid, const inputName[])
{
	new 
		id = cache_insert_id(dbHandle);
	
	orgInfo[id][orgID] =
	pInfo[playerid][pOrganization] = id;

	pInfo[playerid][pOrgRank] = 8;

	SetString(orgInfo[id][orgName], inputName);
	SetString(orgInfo[id][orgLeader], GetName(playerid));

	for(new i = 0; i < MAX_RANKS; i++)
	{
		new
			rankName[7];

		format(rankName, sizeof rankName, "%d ранг", i + 1);
		SetString(orgRanks[id][i], rankName);
	}

	SaveOrganization(id);
	SaveAccount(playerid);

	return 1;
}

@OrgOffUninvite(playerid, const name[]);
@OrgOffUninvite(playerid, const name[])
{
	new rows, fields;
 	cache_get_data(rows, fields);

	if(rows)
	{
		if(cache_get_row_int(0, 0, dbHandle) >= pInfo[playerid][pOrgRank])
			return SendClientMessage(playerid, 0xFF0000FF, !"Вы не можете выгнать этого игрока");
 
		format_mysql("UPDATE `accounts` SET `organization` = 0 AND `org_rank` = 0 WHERE name = '%s'", name);
		mysql_tquery(dbHandle, mysqlString, "", "");

		format_string("Вы выгнали %s из организации", name);
		SendClientMessage(playerid, 0xFF0000FF, formatString);
	}
	else
		return SendClientMessage(playerid, 0xFF0000FF, !"Игрок не найден или не состоит в Вашей организации"); 

	return 1;
}