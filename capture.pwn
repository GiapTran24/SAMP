#include <a_samp>
#include <zcmd>
#include <sscanf2>
#include <streamer>
#include <YSI\y_hooks>

#define CAPTURES_FILE "capture_zones.txt"
#define MAX_CAPTURE_ZONES   20
#define CAPTURE_TIME        50
#define COLOR_NEUTRAL       0xFFFFFF66

new GangColor[MAX_FAMILY] =
{
    0xFF0000AA, 0x00FF00AA, 0x0000FFAA, 0xFFFF00AA, 0xFF00FFAA,
    0x00FFFFFF, 0xFFA500AA, 0x800080AA, 0x008080AA, 0xFFFFFFAA
};

new bool:PlayerInZone[MAX_PLAYERS][MAX_CAPTURE_ZONES];
new PlayerZone[MAX_PLAYERS];
new PlayerText:BarText[MAX_PLAYERS];
new bool:UICreated[MAX_PLAYERS];
new PlayerText:TurfUI[MAX_PLAYERS][6];
new bool:TurfUICreated[MAX_PLAYERS];
new FlashState[MAX_CAPTURE_ZONES];

enum czInfo
{
    bool:czExists,
    Float:czX,  Float:czY,  Float:czZ,
    Float:czRadius,
    Float:czMinX, Float:czMinY, Float:czMaxX, Float:czMaxY,

    czOwnerGang,
    czCapturingGang,
    czProgress,
    czContested,
    czArea,
    czGangZone, 
    Text3D:czLabel,
    czPickup
};
new CaptureZone[MAX_CAPTURE_ZONES][czInfo];

stock SaveCPZones() {
    new File:f = fopen(CAPTURES_FILE, io_write);
    if(!f) return 0;

    new line[256];

    for(new i; i < MAX_CAPTURE_ZONES; i++) {
        if(!CaptureZone[i][czExists]) continue;

        format(line, sizeof(line), "%d|%f|%f|%f|%f|%d\n",
            i,
            CaptureZone[i][czX],
            CaptureZone[i][czY],
            CaptureZone[i][czZ],
            CaptureZone[i][czRadius],
            CaptureZone[i][czOwnerGang]
        );
        fwrite(f, line);
    }
    fclose(f);
    return 1;
}

stock LoadCPZones() {
    if (!fexist(CAPTURES_FILE)) return 1;

    new File:f = fopen(CAPTURES_FILE, io_read);
    if (!f) return 0;

    new line[256];
    new id;
    new Float:x, Float:y, Float:z, Float:radius, ownerGang;

    while (fread(f, line))
    {
        if (sscanf(line, "p<|>dffffd", id, x, y, z, radius, ownerGang))
            continue;

        CaptureZone[id][czOwnerGang] = ownerGang;
        CreateZone(id, x, y, z, radius);
    }

    fclose(f);
    return 1;
}

stock CreateCaptureUI(playerid)
{
    if (UICreated[playerid]) DestroyCaptureUI(playerid);

    BarText[playerid] = CreatePlayerTextDraw(playerid, 320.0, 360.0, "...");
    PlayerTextDrawAlignment(playerid, BarText[playerid], 2);
    PlayerTextDrawColor(playerid, BarText[playerid], 0xFFFFFFFF);
    PlayerTextDrawLetterSize(playerid, BarText[playerid], 0.35, 1.5);
    PlayerTextDrawSetOutline(playerid, BarText[playerid], 1);

    UICreated[playerid] = true;
}

stock CreateTurfUI(playerid)
{
    if(TurfUICreated[playerid]) return;

    // BOX
    TurfUI[playerid][0] = CreatePlayerTextDraw(playerid, 500.0, 150.0, "_");
    PlayerTextDrawTextSize(playerid, TurfUI[playerid][0], 640.0, 320.0);

    // TITLE
    TurfUI[playerid][1] = CreatePlayerTextDraw(playerid, 510.0, 160.0, "ZONE");
    PlayerTextDrawLetterSize(playerid, TurfUI[playerid][1], 0.3, 1.2);

    // STATUS
    TurfUI[playerid][2] = CreatePlayerTextDraw(playerid, 510.0, 190.0, "STATUS");
    PlayerTextDrawLetterSize(playerid, TurfUI[playerid][2], 0.25, 1.0);

    // PROGRESS
    TurfUI[playerid][3] = CreatePlayerTextDraw(playerid, 510.0, 220.0, "PROGRESS");
    PlayerTextDrawLetterSize(playerid, TurfUI[playerid][3], 0.25, 1.0);

    // GANG LIST
    TurfUI[playerid][4] = CreatePlayerTextDraw(playerid, 510.0, 250.0, "GANGS");
    PlayerTextDrawLetterSize(playerid, TurfUI[playerid][4], 0.25, 1.0);

    // FOOTER (optional)
    TurfUI[playerid][5] = CreatePlayerTextDraw(playerid, 510.0, 300.0, "_");

    TurfUICreated[playerid] = true;
}

stock GetProgressBar(percent)
{
    static bar[32];
    new filled = percent / 10; // 10 ô

    format(bar, sizeof(bar), "[");

    for(new i; i < 10; i++)
    {
        if(i < filled) strcat(bar, "|");
        else strcat(bar, "-");
    }

    strcat(bar, "]");

    return bar;
}

stock UpdateTurfUI(playerid, zoneid)
{
    if(zoneid == -1) return;

    CreateTurfUI(playerid);

    new str[256];

    // ===== TITLE =====
    format(str, sizeof(str), "ZONE (#%d)", zoneid);
    PlayerTextDrawSetString(playerid, TurfUI[playerid][1], str);

    // ===== STATUS =====
    if(CaptureZone[zoneid][czContested])
        format(str, sizeof(str), "~r~STATUS: Tran Chap");
    else if(CaptureZone[zoneid][czCapturingGang] != -1)
        format(str, sizeof(str), "~y~STATUS: Dang Chiem");
    else if(CaptureZone[zoneid][czOwnerGang] != -1)
        format(str, sizeof(str), "~g~OWNER: %s", FamilyInfo[CaptureZone[zoneid][czOwnerGang]][FamilyName]);
    else
        format(str, sizeof(str), "STATUS: None");

    PlayerTextDrawSetString(playerid, TurfUI[playerid][2], str);

    // ===== PROGRESS =====
    new percent = (CaptureZone[zoneid][czProgress] * 100) / CAPTURE_TIME;
    format(str, sizeof(str), "PROGRESS: %s %d%%", GetProgressBar(percent), percent);
    if(CaptureZone[zoneid][czOwnerGang] != -1) {
        format(str, sizeof(str), "~g~PROGRESS: 100%");
    }
    PlayerTextDrawSetString(playerid, TurfUI[playerid][3], str);

    // ===== GANG LIST =====
    new gangText[256];
    strcat(gangText, "GANGS:\n\n");

    new counts[MAX_FAMILY];

    foreach(new p : Player)
    {
        if(PlayerZone[p] != zoneid) continue;

        new g = PlayerInfo[p][pFMember];
        if(g >= 0) counts[g]++;
    }

    for(new g; g < MAX_FAMILY; g++)
    {
        if(counts[g] <= 0) continue;

        new line[128];

        if(g == CaptureZone[zoneid][czCapturingGang])
        {
            format(line, sizeof(line), "~y~%s (%d)\n",
                FamilyInfo[g][FamilyName],
                counts[g]
            );
        }
        else
        {
            format(line, sizeof(line), "- %s (%d)\n",
                FamilyInfo[g][FamilyName],
                counts[g]
            );
        }

        strcat(gangText, line);
    }
    PlayerTextDrawSetString(playerid, TurfUI[playerid][4], gangText);
    if(CaptureZone[zoneid][czOwnerGang] != -1) PlayerTextDrawSetString(playerid, TurfUI[playerid][4], "~g~Chiem thanh cong !");

    for(new i; i < 6; i++)
        PlayerTextDrawShow(playerid, TurfUI[playerid][i]);
}

stock DestroyTurfUI(playerid)
{
    if(!TurfUICreated[playerid]) return;

    for(new i; i < 6; i++)
    {
        if(TurfUI[playerid][i])
        {
            PlayerTextDrawDestroy(playerid, TurfUI[playerid][i]);
            TurfUI[playerid][i] = PlayerText:INVALID_TEXT_DRAW;
        }
    }

    TurfUICreated[playerid] = false;
}

stock DestroyCaptureUI(playerid)
{
    if (!UICreated[playerid]) return;
    PlayerTextDrawDestroy(playerid, BarText[playerid]);
    UICreated[playerid] = false;
}

stock UpdateUI(playerid, percent, const status[])
{
    if (!UICreated[playerid]) return;
    new str[64];
    format(str, sizeof(str), "%s %d%%", status, percent);
    PlayerTextDrawSetString(playerid, BarText[playerid], str);
    PlayerTextDrawShow(playerid, BarText[playerid]);
}

stock CreateZone(id, Float:x, Float:y, Float:z, Float:radius)
{
    CaptureZone[id][czExists]       = true;
    CaptureZone[id][czX]            = x;
    CaptureZone[id][czY]            = y;
    CaptureZone[id][czZ]            = z;
    CaptureZone[id][czRadius]       = radius;
    CaptureZone[id][czCapturingGang] = -1;
    CaptureZone[id][czProgress]     = 0;
    CaptureZone[id][czContested]    = 0;

    CaptureZone[id][czMinX] = x - radius;
    CaptureZone[id][czMinY] = y - radius;
    CaptureZone[id][czMaxX] = x + radius;
    CaptureZone[id][czMaxY] = y + radius;

    CaptureZone[id][czArea] = CreateDynamicSphere(x, y, z, radius);
    CaptureZone[id][czGangZone] = GangZoneCreate(
        CaptureZone[id][czMinX], CaptureZone[id][czMinY], 
        CaptureZone[id][czMaxX], CaptureZone[id][czMaxY]
    );
    CaptureZone[id][czPickup] = CreateDynamicPickup(19198, 23, x, y, z);
    
    new str[128];
    if(CaptureZone[id][czOwnerGang] != -1) {
        format(str, sizeof(str), "#Zone %d\nChu so huu: {FFFF00}%s", id, FamilyInfo[CaptureZone[id][czOwnerGang]][FamilyName]);
    }
    else {
        format(str, sizeof(str), "#Zone %d\n{00FF00}Chua co chu\n{FFFFFF}Su dung /chiem de bat dau", id);
    }
    CaptureZone[id][czLabel] = CreateDynamic3DTextLabel(str, COLOR_NEUTRAL, x, y, z + 0.5, 20.0);
    UpdateZoneTurf(id);
    SaveCPZones();
}

stock UpdateZoneTurf(zoneid)
{
    if(CaptureZone[zoneid][czContested] == 1)
    {
        new color;

        if(FlashState[zoneid] == 0)
        {
            color = 0xFF0000AA; 
            FlashState[zoneid] = 1;
        }
        else
        {
            color = COLOR_NEUTRAL;
            FlashState[zoneid] = 0;
        }

        GangZoneShowForAll(CaptureZone[zoneid][czGangZone], color);
        return;
    }

    if(CaptureZone[zoneid][czCapturingGang] != -1)
    {
        new color;

        if(FlashState[zoneid] == 0)
        {
            color = GangColor[CaptureZone[zoneid][czCapturingGang]];
            FlashState[zoneid] = 1;
        }
        else
        {
            color = COLOR_NEUTRAL;
            FlashState[zoneid] = 0;
        }

        GangZoneShowForAll(CaptureZone[zoneid][czGangZone], color);
        return;
    }

    new gang  = CaptureZone[zoneid][czOwnerGang];
    new color = (gang == -1) ? COLOR_NEUTRAL : GangColor[gang];

    GangZoneShowForAll(CaptureZone[zoneid][czGangZone], color);
}

stock UpdateZoneLabel(zoneid)
{
    new gang  = CaptureZone[zoneid][czOwnerGang];
    new str[255];

    if (gang == -1)
    {
        if (CaptureZone[zoneid][czCapturingGang] != -1)
        {
            new capGang = CaptureZone[zoneid][czCapturingGang];
            format(str, sizeof(str), "#Zone %d\n{FF0000}Dang bi chiem boi: %s\nProgress: %d%%", 
                zoneid, FamilyInfo[capGang][FamilyName], (CaptureZone[zoneid][czProgress] * 100) / CAPTURE_TIME);
            
            if (CaptureZone[zoneid][czContested]) {
                strcat(str, "\n{FF0000}!!! TRANH CHAP !!!");
            }
            UpdateDynamic3DTextLabelText(CaptureZone[zoneid][czLabel], 0xFF0000FF, str);
        }
        else {
            format(str, sizeof(str), "#Zone %d\nTrang thai: {00FF00}Chua co chu\n{FFFFFF}Su dung /chiem de bat dau", zoneid);
            UpdateDynamic3DTextLabelText(CaptureZone[zoneid][czLabel], COLOR_NEUTRAL, str);
        }
    }
    else {
        format(str, sizeof(str), "#Zone %d\nChu so huu: {FFFF00}%s", zoneid, FamilyInfo[gang][FamilyName]);
        UpdateDynamic3DTextLabelText(CaptureZone[zoneid][czLabel], GangColor[gang], str);
    }
}

stock KiemTraRaVaoTurf()
{
    for(new p; p < MAX_PLAYERS; p++)
    {
        // if(!IsPlayerConnected(p)) continue;

        for(new i; i < MAX_CAPTURE_ZONES; i++)
        {
            if(!CaptureZone[i][czExists]) continue;

            if(IsPlayerInDynamicArea(p, CaptureZone[i][czArea]) && !PlayerInZone[p][i])
            {
                PlayerInZone[p][i] = true;
                PlayerZone[p] = i;
                if (CaptureZone[i][czCapturingGang] != -1) CreateCaptureUI(p);
                if (PlayerInfo[p][pFMember] < INVALID_FAMILY_ID) UpdateTurfUI(p, i);
                new str[128];
                format(str, sizeof(str), "**Hay can than! Ban da vao khu vuc chiem dong #%d", i);
                SendClientMessage(p, -1, str);
                break;
            }

            else if(!IsPlayerInDynamicArea(p, CaptureZone[i][czArea]) && PlayerInZone[p][i])
            {
                PlayerInZone[p][i] = false;

                if(PlayerZone[p] == i)
                    PlayerZone[p] = -1;

                DestroyCaptureUI(p);
                DestroyTurfUI(p);
                new str[128];
                format(str, sizeof(str), "**Ban da ra khoi khu vuc chiem dong #%d!", i);
                SendClientMessage(p, -1, str);
                break;
            }
        }
    }
}

hook OnPlayerConnect(playerid)
{
    for(new i; i < MAX_CAPTURE_ZONES; i++)
    {
        if(!CaptureZone[i][czExists]) continue;
        if(CaptureZone[i][czContested]) {
            GangZoneShowForPlayer(playerid, CaptureZone[i][czGangZone], 0xFF0000AA);
            continue;
        }
        if(CaptureZone[i][czCapturingGang] != -1) {
            GangZoneShowForPlayer(playerid, CaptureZone[i][czGangZone], GangColor[CaptureZone[i][czCapturingGang]]);
            continue;
        }
        if(CaptureZone[i][czOwnerGang] != -1) {
            GangZoneShowForPlayer(playerid, CaptureZone[i][czGangZone], GangColor[CaptureZone[i][czOwnerGang]]);
            continue;
        }
        GangZoneShowForPlayer(playerid, CaptureZone[i][czGangZone], COLOR_NEUTRAL);
    }
    return 1;
}

hook OnPlayerDeath(playerid, killerid, reason)
{
    DestroyCaptureUI(playerid);
    DestroyTurfUI(playerid);
    PlayerZone[playerid] = -1;
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    DestroyCaptureUI(playerid);
    DestroyTurfUI(playerid);
    PlayerZone[playerid] = -1;
    return 1;
}

task TurfStreamUpdate[500]()
{
    KiemTraRaVaoTurf();
    for (new i; i < MAX_CAPTURE_ZONES; i++)
    {
        if (!CaptureZone[i][czExists] || CaptureZone[i][czCapturingGang] == -1) continue;

        new capGang = CaptureZone[i][czCapturingGang];
        new capCount = 0, enemyCount = 0;

        foreach (new p : Player)
        {
            if (PlayerZone[p] != i) continue;

            new g = PlayerInfo[p][pFMember];
            if (g == capGang) capCount++;
            else if (g != -1) enemyCount++; 
            UpdateTurfUI(p, i);
        }

        // 1. Nếu không còn ai của gang chiếm trong zone -> Reset
        if (capCount == 0)
        {
            CaptureZone[i][czCapturingGang] = -1;
            CaptureZone[i][czProgress] = 0;
            CaptureZone[i][czContested] = 0;
            UpdateZoneLabel(i);
            UpdateZoneTurf(i); 

            foreach (new p : Player) if(PlayerZone[p] == i) {
                DestroyCaptureUI(p);
                UpdateTurfUI(p, i);
            }
            continue;
        }

        // 2. Xử lý tranh chấp
        if (enemyCount > 0)
        {
            if (!CaptureZone[i][czContested])
            {
                CaptureZone[i][czContested] = 1;
            }
            foreach (new p : Player) 
            {
                if (PlayerZone[p] == i) {
                    UpdateUI(p, (CaptureZone[i][czProgress] * 100) / CAPTURE_TIME, "~r~CONTESTED");
                    UpdateTurfUI(p, i);
                }
            }
            UpdateZoneLabel(i);
            UpdateZoneTurf(i);
            continue; 
        }

        // 3. Không tranh chấp -> Tăng tiến độ
        if (CaptureZone[i][czContested]) 
        {
            CaptureZone[i][czContested] = 0;
        }

        CaptureZone[i][czProgress]++;
        new percent = (CaptureZone[i][czProgress] * 100) / CAPTURE_TIME;
        UpdateZoneLabel(i);
        UpdateZoneTurf(i);

        foreach (new p : Player)
        {
            if (PlayerZone[p] == i) 
            {
                if (PlayerInfo[p][pFMember] == capGang) {
                    UpdateUI(p, percent, "~g~CAPTURING");
                    UpdateTurfUI(p, i);
                }
                else {
                    UpdateUI(p, percent, "~y~DEFENDING");
                    UpdateTurfUI(p, i);
                }
            }
        }

        // 4. Chiếm thành công
        if (CaptureZone[i][czProgress] >= CAPTURE_TIME)
        {
            CaptureZone[i][czOwnerGang] = capGang;
            CaptureZone[i][czCapturingGang] = -1;
            CaptureZone[i][czProgress] = 0;
            
            UpdateZoneTurf(i);
            UpdateZoneLabel(i);
            SaveCPZones();

            foreach (new p : Player) if (PlayerZone[p] == i) {
                DestroyCaptureUI(p);
                UpdateTurfUI(p, i);
            }

            new msg[128];
            format(msg, sizeof(msg), "{FFFF00}[ZONE] {FFFFFF}Gang %s da chiem thanh cong khu vuc #%d!", FamilyInfo[capGang][FamilyName], i);
            SendClientMessageToAll(-1, msg);
        }
    }
    return 1;
}


CMD:chiem(playerid, params[])
{
    new gang = PlayerInfo[playerid][pFMember];
    if(gang == -1) return SendClientMessage(playerid, -1, "Ban khong co Gang.");

    new zone = PlayerZone[playerid];
    if(zone == -1) return SendClientMessage(playerid, -1, "Ban phai dung trong khu vuc Zone!");

    if (!IsPlayerInRangeOfPoint(playerid, 3.0, CaptureZone[zone][czX], CaptureZone[zone][czY], CaptureZone[zone][czZ]))
        return SendClientMessage(playerid, -1, "Ban phai dung ngay diem Pickup de chiem!");

    if (CaptureZone[zone][czOwnerGang] != -1)
        return SendClientMessage(playerid, -1, "Khu nay da co chu, khong the chiem tiep!");

    if (CaptureZone[zone][czCapturingGang] != -1) {
        if (CaptureZone[zone][czCapturingGang] == gang) return SendClientMessage(playerid, -1, "Gang ban dang chiem khu nay roi!");
        return SendClientMessage(playerid, -1, "Khu nay dang bi mot gang khac chiem!");
    }

    CaptureZone[zone][czCapturingGang] = gang;
    CaptureZone[zone][czProgress] = 0;
    
    CreateCaptureUI(playerid);
    
    new msg[128];
    format(msg, sizeof(msg), "{FFFF00}[ZONE] {FFFFFF}Gang %s dang bat dau chiem dong khu vuc #%d!", FamilyInfo[gang][FamilyName], zone);
    SendClientMessageToAll(-1, msg);
    return 1;
}

CMD:czcreate(playerid, params[])
{
    if(PlayerInfo[playerid][pAdmin] < 999990) return SendClientMessage(playerid, COLOR_YELLOW, "Ban khong duoc phep su dung lenh nay.");
    new Float:r, id = -1;
    if (sscanf(params, "f", r)) return SendClientMessage(playerid, -1, "Usage: /czcreate [radius]");

    for (new i; i < MAX_CAPTURE_ZONES; i++) {
        if (!CaptureZone[i][czExists]) { id = i; break; }
    }
    if (id == -1) return SendClientMessage(playerid, -1, "Full slot zone.");

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);

    CaptureZone[id][czOwnerGang] = -1;
    CreateZone(id, x, y, z, r);
    
    SendClientMessage(playerid, 0x00FF00FF, "Tao Zone thanh cong!");
    return 1;
}

CMD:czdelete(playerid, params[])
{
    if(PlayerInfo[playerid][pAdmin] < 999990) return SendClientMessage(playerid, COLOR_YELLOW, "Ban khong duoc phep su dung lenh nay.");

    new id;
    if (sscanf(params, "d", id)) return SendClientMessage(playerid, -1, "Usage: /czdelete [id]");
    if (!CaptureZone[id][czExists]) return SendClientMessage(playerid, -1, "ID khong ton tai.");

    GangZoneDestroy(CaptureZone[id][czGangZone]);
    DestroyDynamic3DTextLabel(CaptureZone[id][czLabel]);
    DestroyDynamicPickup(CaptureZone[id][czPickup]);
    
    foreach(new p : Player) if(PlayerZone[p] == id) { DestroyCaptureUI(p); PlayerZone[p] = -1; }
    
    CaptureZone[id][czExists] = false;
    SendClientMessage(playerid, 0xFF0000FF, "Da xoa zone.");
    return 1;
}