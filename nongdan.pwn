#include <YSI\y_hooks>

// #define MAX_PLANTS          500
#define FARM_ZONE_RADIUS    50.0       
#define GROWTH_RATE         2          
#define WATER_LOSS          3           
#define TICK_TIME           10000       
#define DIALOG_PLANT_SELECT 7001
#define DISEASE_CHANCE      5           
#define DISEASE_DAMAGE      30          

new Float:FarmCenterPos[3] = { -11726.3961,1488.5402,10.6719 }; 

enum E_PLANT_DATA {
    pID,                
    pType,              
    Float:pPos[3],      
    pObject,            
    pGrowth,            
    pWater,             
    pOwnerID,           
    pDisease,           
    bool:pActive,       
    Text3D:pText3D      
}

new PlantData[MAX_PLANTS][E_PLANT_DATA];
new PlayerSeeds[MAX_PLAYERS][3];    // 0: Lua, 1: Ngo, 2: Ca chua
new PlayerMedicine[MAX_PLAYERS];     // SL thuoc khang benh

// Model Object: [0] Mầm, [1] Lúa chín, [2] Ngô chín, [3] Cà chua chín
new const PlantModels[] = {19473, 823, 3409};
new const PlantNames[][] = {"Lua", "Ngo", "Ca chua"};

// --- Hàm hỗ trợ ---
GetPlantNearby(playerid, &index) {
    for(new i = 0; i < MAX_PLANTS; i++) {
        if(PlantData[i][pActive] && IsPlayerInRangeOfPoint(playerid, 2.5, PlantData[i][pPos][0], PlantData[i][pPos][1], PlantData[i][pPos][2])) {
            index = i;
            return 1;
        }
    }
    return 0;
}

UpdatePlant3DText(index) {
    new text[96];
    new status[32] = "Binh Thuong";
    if(PlantData[index][pDisease] > 0) {
        format(status, sizeof(status), "~r~Benh: %d%%", PlantData[index][pDisease]);
    }
    format(text, sizeof(text), "%s\nTruong Thanh: %d%%\nNuoc: %d%%\n%s", PlantNames[PlantData[index][pType]], PlantData[index][pGrowth], PlantData[index][pWater], status);
    Update3DTextLabelText(PlantData[index][pText3D], 0xFFFFFFFF, text);
}

CreatePlantObject(index) {
    if(!PlantData[index][pActive]) return 0;
    PlantData[index][pObject] = CreateObject(PlantModels[0], PlantData[index][pPos][0], PlantData[index][pPos][1], PlantData[index][pPos][2] - 1.2, 0.0, 0.0, 0.0);
    new text[96];
    format(text, sizeof(text), "%s\nTruong Thanh: %d%%\nNuoc: %d%%\nBinh Thuong", PlantNames[PlantData[index][pType]], PlantData[index][pGrowth], PlantData[index][pWater]);
    PlantData[index][pText3D] = Create3DTextLabel(text, 0xFFFFFFFF, PlantData[index][pPos][0], PlantData[index][pPos][1], PlantData[index][pPos][2], 10.0, 0, 1);
    // Attach3DTextLabelToObject(PlantData[index][pText3D], PlantData[index][pObject], 0.0, 0.0, 1.0);
    return 1;
}

SavePlantToSQL(index) {
    if(!PlantData[index][pActive]) return 0;
    new query[512];
    if(PlantData[index][pID] == 0) {
        // Insert mới
        format(query, sizeof(query), "INSERT INTO `fplants` (`type`, `x`, `y`, `z`, `growth`, `water`, `disease`, `owner_id`, `active`) VALUES ('%d', '%.2f', '%.2f', '%.2f', '%d', '%d', '%d', '%d', '1')",
            PlantData[index][pType], PlantData[index][pPos][0], PlantData[index][pPos][1], PlantData[index][pPos][2],
            PlantData[index][pGrowth], PlantData[index][pWater], PlantData[index][pDisease], PlantData[index][pOwnerID]);
        mysql_function_query(MainPipeline, query, true, "OnPlantInserted", "i", index);
    } else {
        // Update
        format(query, sizeof(query), "UPDATE `fplants` SET `growth`='%d', `water`='%d', `disease`='%d' WHERE `id`='%d'",
            PlantData[index][pGrowth], PlantData[index][pWater], PlantData[index][pDisease], PlantData[index][pID]);
        mysql_function_query(MainPipeline, query, false, "OnQueryFinish", "i", SENDDATA_THREAD);
    }
    return 1;
}

forward OnPlantInserted(index);
public OnPlantInserted(index) {
    if(cache_num_rows() > 0) {
        PlantData[index][pID] = cache_insert_id();
    }
    return 1;
}

DeletePlantFromSQL(index) {
    if(PlantData[index][pID] == 0) return 0;
    new query[128];
    format(query, sizeof(query), "DELETE FROM `fplants` WHERE `id`='%d'", PlantData[index][pID]);
    mysql_function_query(MainPipeline, query, false, "OnQueryFinish", "i", SENDDATA_THREAD);
    PlantData[index][pID] = 0;
    return 1;
}

LoadAllPlantsFromSQL() {
    new query[100] = "SELECT * FROM `fplants` WHERE `active`='1'";
    mysql_function_query(MainPipeline, query, true, "OnPlantsLoaded", "");
    return 1;
}

forward OnPlantsLoaded();
public OnPlantsLoaded() {
    new rows = cache_num_rows();
    if(rows == 0) return 1;
    
    new index = 0;
    for(new i = 0; i < rows && index < MAX_PLANTS; i++) {
        if(PlantData[index][pActive]) {
            index++;
            i--;
            continue;
        }
        
        PlantData[index][pID] = cache_get_field_content_int(i, "id");
        PlantData[index][pType] = cache_get_field_content_int(i, "type");
        PlantData[index][pPos][0] = cache_get_field_content_float(i, "x");
        PlantData[index][pPos][1] = cache_get_field_content_float(i, "y");
        PlantData[index][pPos][2] = cache_get_field_content_float(i, "z");
        PlantData[index][pGrowth] = cache_get_field_content_int(i, "growth");
        PlantData[index][pWater] = cache_get_field_content_int(i, "water");
        PlantData[index][pDisease] = cache_get_field_content_int(i, "disease");
        PlantData[index][pOwnerID] = cache_get_field_content_int(i, "owner_id");
        PlantData[index][pActive] = true;
        
        CreatePlantObject(index);
        UpdatePlant3DText(index);
        index++;
    }
    
    printf("[FARM] Loaded %d plants from database", rows);
    return 1;
}

hook OnGameModeInit()
{
    SetTimer("PlantProcessTimer", TICK_TIME, true);
    LoadAllPlantsFromSQL();
    return 1;
}

forward PlantProcessTimer();
public PlantProcessTimer()
{
    for(new i = 0; i < MAX_PLANTS; i++)
    {
        if(!PlantData[i][pActive]) continue;

        if(PlantData[i][pWater] > 0) PlantData[i][pWater] -= WATER_LOSS;
        if(PlantData[i][pWater] < 0) PlantData[i][pWater] = 0;

        if(PlantData[i][pDisease] > 0) {
            PlantData[i][pDisease] += 2;
            if(PlantData[i][pDisease] >= 100) {
                Delete3DTextLabel(PlantData[i][pText3D]);
                DestroyObject(PlantData[i][pObject]);
                DeletePlantFromSQL(i);
                PlantData[i][pActive] = false;
                continue;
            }
        }

        if(random(100) < DISEASE_CHANCE && PlantData[i][pDisease] == 0) {
            PlantData[i][pDisease] = 1;
        }

        if(PlantData[i][pWater] > 0 && PlantData[i][pGrowth] < 100 && PlantData[i][pDisease] < DISEASE_DAMAGE)
        {
            PlantData[i][pGrowth] += GROWTH_RATE;

            if(PlantData[i][pGrowth] >= 100)
            {
                PlantData[i][pGrowth] = 100;
                new modelid = PlantModels[PlantData[i][pType] + 1];
                
                DestroyObject(PlantData[i][pObject]);
                PlantData[i][pObject] = CreateObject(modelid, PlantData[i][pPos][0], PlantData[i][pPos][1], PlantData[i][pPos][2] - 1.0, 0.0, 0.0, 0.0);
                // Attach3DTextLabelToObject(PlantData[i][pText3D], PlantData[i][pObject], 0.0, 0.0, 1.0);
            }
        }
        
        UpdatePlant3DText(i);
    }
    
    static save_counter = 0;
    save_counter++;
    if(save_counter >= 6) { 
        for(new i = 0; i < MAX_PLANTS; i++) {
            if(PlantData[i][pActive]) {
                SavePlantToSQL(i);
            }
        }
        save_counter = 0;
    }
    return 1;
}

CMD:trongcay(playerid, params[])
{
    // if(!IsPlayerInRangeOfPoint(playerid, FARM_ZONE_RADIUS, FarmCenterPos[0], FarmCenterPos[1], FarmCenterPos[2]))
    //     return SendClientMessageEx(playerid, 0xFF0000FF, "Ban phai o khu vuc trang trai moi co the trong cay!");

    new list[128];
    format(list, sizeof(list), "Lua (%d hat)\nNgo (%d hat)\nCa chua (%d hat)", PlayerSeeds[playerid][0], PlayerSeeds[playerid][1], PlayerSeeds[playerid][2]);
    ShowPlayerDialog(playerid, DIALOG_PLANT_SELECT, DIALOG_STYLE_LIST, "Chon loai cay trong", list, "Trong", "Huy");
    return 1;
}

CMD:tuoinuoc(playerid, params[])
{
    new index;
    if(!GetPlantNearby(playerid, index)) return SendClientMessageEx(playerid, -1, "Ban khong dung gan cay nao!");
    if(PlantData[index][pOwnerID] != GetPlayerSQLId(playerid)) return SendClientMessageEx(playerid, -1, "Day khong phai cay cua ban!");
    
    PlantData[index][pWater] = 100;
    SavePlantToSQL(index);
    ApplyAnimation(playerid, "PARKING", "Gw_Spray", 4.1, 0, 0, 0, 0, 0, 1);
    UpdatePlant3DText(index);
    SendClientMessageEx(playerid, 0x33CCFFFF, "Ban da tuoi nuoc cho cay!");
    return 1;
}

CMD:thuhoach(playerid, params[])
{
    new index;
    if(!GetPlantNearby(playerid, index)) return SendClientMessageEx(playerid, -1, "Khong co cay nao o gan day.");
    if(PlantData[index][pOwnerID] != GetPlayerSQLId(playerid)) return SendClientMessageEx(playerid, -1, "Day khong phai cay cua ban!");
    if(PlantData[index][pGrowth] < 100) return SendClientMessageEx(playerid, 0xFF0000FF, "Cay nay chua chin, hay doi tiep!");
    if(PlantData[index][pDisease] > 50) return SendClientMessageEx(playerid, 0xFF0000FF, "Cay bi benh qua nang, khong the thu hoach!");

    Delete3DTextLabel(PlantData[index][pText3D]);
    DestroyObject(PlantData[index][pObject]);
    DeletePlantFromSQL(index);
    PlantData[index][pActive] = false;
    
    new reward = (100 + random(100)) - (PlantData[index][pDisease] / 2);
    GivePlayerCash(playerid, reward);
    
    new str[96];
    format(str, sizeof(str), "Ban da thu hoach %s va nhan duoc $%d!", PlantNames[PlantData[index][pType]], reward);
    SendClientMessageEx(playerid, 0xFFFF00FF, str);
    return 1;
}

CMD:muahatgiong(playerid, params[])
{
    new type, quantity;
    if(sscanf(params, "dd", type, quantity)) return SendClientMessageEx(playerid, -1, "Su dung: /muahatgiong [loai] [so luong] (0-2)");
    if(type < 0 || type > 2 || quantity <= 0) return SendClientMessageEx(playerid, -1, "Loai khong hop le hoac so luong sai.");
    new price = 50 * quantity;
    if(GetPlayerMoney(playerid) < price) return SendClientMessageEx(playerid, -1, "Ban khong du tien!");
    GivePlayerCash(playerid, -price);
    PlayerSeeds[playerid][type] += quantity;
    new str[96];
    format(str, sizeof(str), "Ban da mua %d hat giong %s voi gia $%d.", quantity, PlantNames[type], price);
    SendClientMessageEx(playerid, 0x00FF00FF, str);
    return 1;
}

CMD:xemhatgiong(playerid, params[])
{
    new str[200];
    format(str, sizeof(str), "Hat giong cua ban:\nLua: %d\nNgo: %d\nCa chua: %d\n\nThuoc (Khang Benh): %d", PlayerSeeds[playerid][0], PlayerSeeds[playerid][1], PlayerSeeds[playerid][2], PlayerMedicine[playerid]);
    SendClientMessageEx(playerid, -1, str);
    return 1;
}

CMD:muathuoc(playerid, params[])
{
    new quantity;
    if(sscanf(params, "d", quantity)) return SendClientMessageEx(playerid, -1, "Su dung: /muathuoc [so luong]");
    if(quantity <= 0) return SendClientMessageEx(playerid, -1, "So luong phai lon hon 0!");
    new price = 100 * quantity;
    if(GetPlayerMoney(playerid) < price) return SendClientMessageEx(playerid, -1, "Ban khong du tien!");
    GivePlayerCash(playerid, -price);
    PlayerMedicine[playerid] += quantity;
    new str[64];
    format(str, sizeof(str), "Ban da mua %d dung dich thuoc voi gia $%d.", quantity, price);
    SendClientMessageEx(playerid, 0x00FF00FF, str);
    return 1;
}

CMD:phunthuoc(playerid, params[])
{
    new index;
    if(!GetPlantNearby(playerid, index)) return SendClientMessageEx(playerid, -1, "Ban khong dung gan cay nao!");
    if(PlantData[index][pOwnerID] != GetPlayerSQLId(playerid)) return SendClientMessageEx(playerid, -1, "Day khong phai cay cua ban!");
    if(PlantData[index][pDisease] == 0) return SendClientMessageEx(playerid, -1, "Cay nay khong bi benh!");
    if(PlayerMedicine[playerid] <= 0) return SendClientMessageEx(playerid, -1, "Ban khong co thuoc!");
    
    PlantData[index][pDisease] = 0;
    PlayerMedicine[playerid]--;
    SavePlantToSQL(index);
    ApplyAnimation(playerid, "PAINTING", "PAINT_WALK", 4.1, 0, 0, 0, 0, 0, 1);
    UpdatePlant3DText(index);
    SendClientMessageEx(playerid, 0x00FF00FF, "Ban da phun thuoc cho cay!");
    return 1;
}

hook OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
    if(dialogid == DIALOG_PLANT_SELECT)
    {
        if(!response) return 1;
        if(listitem < 0 || listitem > 2) return 1;
        if(PlayerSeeds[playerid][listitem] <= 0) return SendClientMessageEx(playerid, -1, "Ban khong co hat giong loai nay!");

        new slot = -1;
        for(new i = 0; i < MAX_PLANTS; i++) {
            if(!PlantData[i][pActive]) {
                slot = i;
                break;
            }
        }

        if(slot == -1) return SendClientMessageEx(playerid, -1, "Khong con cho trong tren canh dong!");

        new Float:x, Float:y, Float:z;
        GetPlayerPos(playerid, x, y, z);

        PlantData[slot][pActive] = true;
        PlantData[slot][pType] = listitem;
        PlantData[slot][pOwnerID] = GetPlayerSQLId(playerid);
        PlantData[slot][pPos][0] = x;
        PlantData[slot][pPos][1] = y;
        PlantData[slot][pPos][2] = z;
        PlantData[slot][pGrowth] = 0;
        PlantData[slot][pWater] = 100;
        PlantData[slot][pDisease] = 0;
        PlantData[slot][pID] = 0;
        
        CreatePlantObject(slot);
        SavePlantToSQL(slot);
        
        PlayerSeeds[playerid][listitem]--;
        
        ApplyAnimation(playerid, "BOMBER", "BOM_Plant", 4.1, 0, 0, 0, 0, 0, 1);
        new str[128];
        format(str, sizeof(str), "Ban da gieo hat %s. Hay nho tuoi nuoc thuong xuyen!", PlantNames[listitem]);
        SendClientMessageEx(playerid, 0x00FF00FF, str);
        return 1;
    }
    return 0;
}
