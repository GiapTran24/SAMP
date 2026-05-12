#include <a_samp>
#include <zcmd>
#include <sscanf2>
#include <YSI\y_hooks>

#define MAX_GANGLOCKER 100
#define MAX_GANG_WEAPONS 10
#define GANGLOCKER_FILE "GangLockers.cfg"
#define GANG_WEAPON_FILE "GangWeapons.cfg"
#define DIALOG_GANGLOCKER 6100
#define DIALOG_GANGGLWEAPON 6101

enum e_GangLocker
{
    Float:glX,
    Float:glY,
    Float:glZ,
    glGangID,
    bool:glExists,
    glPickup,
    Text3D:glText
};

enum e_GangWeapon
{
    gwWeaponID,
    gwAmmo,
    gwMinRank,
    bool:gwEnabled
};

new GangWeapons[MAX_GANGLOCKER][MAX_GANG_WEAPONS][e_GangWeapon];

new GangLocker[MAX_GANGLOCKER][e_GangLocker];
new PlayerGLocker[MAX_PLAYERS];

stock LoadGangLockers()
{
    if (!fexist(GANGLOCKER_FILE)) return 1;

    new File:f = fopen(GANGLOCKER_FILE, io_read);
    if (!f) return 0;

    new line[128], i = 0;

    while (fread(f, line))
    {
        if (sscanf(line, "p<|>fffi",
            GangLocker[i][glX],
            GangLocker[i][glY],
            GangLocker[i][glZ],
            GangLocker[i][glGangID])) continue;

        GangLocker[i][glExists] = true;

        // Create Pickup
        GangLocker[i][glPickup] = CreateDynamicPickup(
            1254, 23,
            GangLocker[i][glX],
            GangLocker[i][glY],
            GangLocker[i][glZ]
        );

        // Get gang id
        new gangid = GangLocker[i][glGangID];

        new str[128];
        printf("Locker %d - GangID: %d - Name: %s",
            i,
            gangid,
            FamilyInfo[gangid][FamilyName]);

        // Check gang hợp lệ
        if(gangid >= 0 && gangid < MAX_FAMILY)
        {
            format(str, sizeof(str),
                "{00FF00}Gang Locker ID: %d\n{FFFFFF}Owner: %s\n/glocker",
                i,
                FamilyInfo[gangid][FamilyName]
            );
        }
        else
        {
            format(str, sizeof(str),
                "{00FF00}Gang Locker ID: %d\n{FFFFFF}Owner: Unknown\n/glocker",
                i
            );
        }

        GangLocker[i][glText] = CreateDynamic3DTextLabel(
            str,
            -1,
            GangLocker[i][glX],
            GangLocker[i][glY],
            GangLocker[i][glZ] + 0.5,
            15.0
        );

        i++;
        if (i >= MAX_GANGLOCKER) break;
    }

    fclose(f);
    return 1;
}

stock LoadGangWeapons()
{
    if(!fexist(GANG_WEAPON_FILE)) return 1;

    new File:f = fopen(GANG_WEAPON_FILE, io_read);
    if(!f) return 0;

    new line[128];

    while(fread(f, line))
    {
        new g, wid, ammo;
        sscanf(line, "p<|>iii", g, wid, ammo);

        for(new i; i < MAX_GANG_WEAPONS; i++)
        {
            if(!GangWeapons[g][i][gwEnabled])
            {
                GangWeapons[g][i][gwWeaponID] = wid;
                GangWeapons[g][i][gwAmmo] = ammo;
                GangWeapons[g][i][gwEnabled] = true;
                break;
            }
        }
    }

    fclose(f);
    return 1;
}

stock SaveGangLockers()
{
    new File:f = fopen(GANGLOCKER_FILE, io_write);
    if (!f) return 0;

    new line[128];

    for (new i; i < MAX_GANGLOCKER; i++)
    {
        if (!GangLocker[i][glExists]) continue;

        format(line, sizeof(line), "%f|%f|%f|%d\n",
               GangLocker[i][glX],
               GangLocker[i][glY],
               GangLocker[i][glZ],
               GangLocker[i][glGangID]);

        fwrite(f, line);
    }

    fclose(f);
    return 1;
}
stock SaveGangWeapons()
{
    new File:f = fopen(GANG_WEAPON_FILE, io_write);
    if(!f) return 0;

    new line[128];

    for(new g; g < MAX_GANGLOCKER; g++)
    {
        for(new i; i < MAX_GANG_WEAPONS; i++)
        {
            if(!GangWeapons[g][i][gwEnabled]) continue;

            format(line, sizeof(line), "%d|%d|%d|%d|%d\n",
                g,
                GangWeapons[g][i][gwWeaponID],
                GangWeapons[g][i][gwAmmo],
                GangWeapons[g][i][gwMinRank],
                GangWeapons[g][i][gwEnabled]);
            fwrite(f, line);
        }
    }

    fclose(f);
    
    return 1;
}

stock GetFreeGangLocker()
{
    for (new i; i < MAX_GANGLOCKER; i++)
    {
        if (!GangLocker[i][glExists])
            return i;
    }
    return -1;
}

// hook OnGameModeInit()
// {
//     LoadGangLockers();
//     LoadGangWeapons();
//     return 1;
// }

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_GANGLOCKER && response)
    {
        switch(listitem)
        {
            case 0: 
            {
                new Float:hp;
                GetPlayerHealth(playerid, hp);
                if(hp >= 100.0) return SendClientMessage(playerid, -1, "Mau cua ban dang day!");

                SetPlayerHealth(playerid, 100.0);
                SendClientMessage(playerid, -1, "Ban da lay mau!");
            }

            case 1: 
            {
                new Float:armor;
                GetPlayerArmour(playerid, armor);
                if(armor >= 100.0) return SendClientMessage(playerid, -1, "Giap cua ban da day!");

                SetPlayerArmor(playerid, 100.0);
                SendClientMessage(playerid, -1, "Ban da lay giap!");
            }

            case 2: 
            {
                new str[512];
                new wpName[50];
                str = "";
                new stt = 0;
                new iLocker = PlayerGLocker[playerid];

                for(new i; i < MAX_GANG_WEAPONS; i++)
                {
                    if(!GangWeapons[iLocker][i][gwEnabled]) continue;
                    GetWeaponName(GangWeapons[iLocker][i][gwWeaponID], wpName, sizeof(wpName));
                    format(str, sizeof(str), "%s%s \n",
                        str,
                        wpName);
                        //GangWeapons[iLocker][i][gwAmmo]);
                    stt++;
                }
                if(stt < 1) return SendClientMessage(playerid, -1, "** Khong co weapon nao trong locker!");
                ShowPlayerDialog(playerid, DIALOG_GANGGLWEAPON, DIALOG_STYLE_LIST, "Weapons Locker", str, "OK", "EXIT");
            }

        }
    }
    if(dialogid == DIALOG_GANGGLWEAPON && response)
    {
        if(PlayerInfo[playerid][pLevel] < 2)
        return SendClientMessage(playerid, -1, "Ban phai dat level 2 moi lay duoc vu khi!");
        new iLocker = PlayerGLocker[playerid];
        if(!GangWeapons[iLocker][listitem][gwEnabled]) return 1;
        if(PlayerInfo[playerid][pRank] < GangWeapons[iLocker][listitem][gwMinRank]) return SendClientMessage(playerid, -1, "Ban khong du rank!");

        new wid = GangWeapons[iLocker][listitem][gwWeaponID];
        if(GetPlayerWeapon(playerid) == wid) return SendClientMessage(playerid, -1, "Ban da co weapon nay!");
        GivePlayerValidWeapon(playerid, wid, GangWeapons[iLocker][listitem][gwAmmo]);

        SendClientMessage(playerid, -1, "Ban da lay weapon!");
    }
    return 0;
}

CMD:createglocker(playerid, params[])
{
    if(PlayerInfo[playerid][pAdmin] < 999990) 
        return SendClientMessage(playerid, COLOR_YELLOW, "Ban khong duoc phep su dung lenh nay.");

    new gangid;
    if (sscanf(params, "i", gangid)) 
        return SendClientMessage(playerid, -1, "Usage: /createglocker [gangid]");

    new id = GetFreeGangLocker();
    if (id == -1) 
        return SendClientMessage(playerid, -1, "Het slot glocker!");

    GetPlayerPos(playerid, GangLocker[id][glX], GangLocker[id][glY], GangLocker[id][glZ]);

    GangLocker[id][glGangID] = gangid;
    GangLocker[id][glExists] = true;

    GangLocker[id][glPickup] = CreateDynamicPickup(1254, 23, 
        GangLocker[id][glX], 
        GangLocker[id][glY], 
        GangLocker[id][glZ]
    );

    new str[128];

    format(str, sizeof(str), 
        "{00FF00}Gang Locker ID: %d\n{FFFFFF}Owner: %s\n/glocker",
        id,
        FamilyInfo[gangid][FamilyName]
    );

    GangLocker[id][glText] = CreateDynamic3DTextLabel(
        str, 
        -1, 
        GangLocker[id][glX], 
        GangLocker[id][glY], 
        GangLocker[id][glZ] + 0.5, 
        15.0
    );

    SaveGangLockers();
    SendClientMessage(playerid, -1, "Da tao Gang Locker!");
    return 1;
}

CMD:deleteglocker(playerid, params[])
{
    if(PlayerInfo[playerid][pAdmin] < 999990) return SendClientMessage(playerid, COLOR_YELLOW, "Ban khong duoc phep su dung lenh nay.");
    new id;
    if (sscanf(params, "i", id)) return SendClientMessage(playerid, -1, "Usage: /deleteglocker [id]");

    if (id < 0 || id >= MAX_GANGLOCKER || !GangLocker[id][glExists]) return SendClientMessage(playerid, -1, "ID Khong hop le!");

    DestroyDynamicPickup(GangLocker[id][glPickup]);
    DestroyDynamic3DTextLabel(GangLocker[id][glText]);

    GangLocker[id][glExists] = false;

    SaveGangLockers();

    SendClientMessage(playerid, -1, "Da xoa Gang Locker!");
    return 1;
}

CMD:addglweapon(playerid, params[])
{
    if(PlayerInfo[playerid][pAdmin] < 999990) return SendClientMessage(playerid, COLOR_YELLOW, "Ban khong duoc phep su dung lenh nay.");

    new lockerid, weaponid, ammo;

    if(sscanf(params, "iiii", lockerid, weaponid, ammo))
        return SendClientMessage(playerid, -1, "Usage: /addglweapon [glockerid] [weaponid] [ammo]");

    for(new i; i < MAX_GANG_WEAPONS; i++)
    {
        if(!GangWeapons[lockerid][i][gwEnabled])
        {
            GangWeapons[lockerid][i][gwWeaponID] = weaponid;
            GangWeapons[lockerid][i][gwAmmo] = ammo;
            //GangWeapons[lockerid][i][gwMinRank] = rank;
            GangWeapons[lockerid][i][gwEnabled] = true;
            SaveGangWeapons();

            SendClientMessage(playerid, -1, "Da them weapon vao locker!");
            return 1;
        }
    }

    return SendClientMessage(playerid, -1, "Het slot weapon!");
}

CMD:removeglweapon(playerid, params[])
{
    if(PlayerInfo[playerid][pAdmin] < 999990) return SendClientMessage(playerid, COLOR_YELLOW, "Ban khong duoc phep su dung lenh nay.");
    new lockerid, slot;
    if(sscanf(params, "ii", lockerid, slot))
        return SendClientMessage(playerid, -1, "Usage: /removeglweapon [glockerid] [slot]");

    GangWeapons[lockerid][slot][gwEnabled] = false;
    SaveGangWeapons();

    SendClientMessage(playerid, -1, "Da xoa weapon!");
    return 1;
}

CMD:glocker(playerid, params[])
{
    new gid = PlayerInfo[playerid][pFMember];
    if (gid >= INVALID_FAMILY_ID)
        return SendClientMessage(playerid, -1, "Ban khong co Gang!");
    if(IsPlayerInAnyVehicle(playerid)) return SendClientMessage(playerid, -1, "Khong the lam dieu nay khi đang trong xe!");

    for (new i; i < MAX_GANGLOCKER; i++)
    {
        if (!GangLocker[i][glExists]) continue;

        if (GangLocker[i][glGangID] != gid) continue;

        if (IsPlayerInRangeOfPoint(playerid, 3.0, GangLocker[i][glX], GangLocker[i][glY], GangLocker[i][glZ]))
        {
            PlayerGLocker[playerid] = i;
            ShowPlayerDialog(playerid, DIALOG_GANGLOCKER, DIALOG_STYLE_LIST, "Gang Locker", "Health\nArmor\nWeapons", "OK", "EXIT");
            return 1;
        }
    }
    return SendClientMessage(playerid, -1, "Ban khong o gan Gocker cua gang!");
}
