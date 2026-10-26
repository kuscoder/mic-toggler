#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

;@Ahk2Exe-SetName Mic Toggle
;@Ahk2Exe-SetDescription Mic Toggle
;@Ahk2Exe-SetCopyright MIT License
;@Ahk2Exe-SetVersion 1.0.0
;@Ahk2Exe-SetMainIcon assets\mic_on.ico

; ================= Constants =================
APP_NAME    := "Mic Toggle"
DATA_DIR    := A_AppData "\MicToggle"
INI         := DATA_DIR "\settings.ini"
ICON_ON     := DATA_DIR "\mic_on.ico"
ICON_OFF    := DATA_DIR "\mic_off.ico"
STARTUP_LNK := A_Startup "\Mic Toggle.lnk"
DEFAULT_HK  := "^!vk4D"   ; Ctrl+Alt+M
REPO_URL    := "https://github.com/kuscoder/mic-toggler"

; Icons are embedded into the exe at compile time and extracted to AppData
DirCreate(DATA_DIR)
FileInstall("assets\mic_on.ico", ICON_ON, 1)
FileInstall("assets\mic_off.ico", ICON_OFF, 1)

; ================= Settings =================
HK := IniRead(INI, "main", "hotkey", DEFAULT_HK)
; reset hotkeys saved by older versions as layout-specific characters
if RegExMatch(HK, "[^\x{20}-\x{7E}]")
    HK := DEFAULT_HK
BeepOn   := IniRead(INI, "main", "beep", "1") = "1"
MicId    := IniRead(INI, "main", "mic_id", "")     ; "" = Windows default microphone
MicLabel := IniRead(INI, "main", "mic_name", "")   ; name of the selected device, shown while it's disconnected
Lang     := IniRead(INI, "main", "lang", SubStr(A_Language, -2) = "19" ? "ru" : "en")
if !(Lang = "en" || Lang = "ru")
    Lang := "en"
HkGui   := 0
LastKey := ""

; ================= Localization =================
STRINGS := Map(
    "en", Map(
        "mute",        "Mute microphone",
        "unmute",      "Unmute microphone",
        "microphone",  "Microphone",
        "default_mic", "Windows default",
        "hotkey",      "Hotkey: ",
        "beep",        "Sound feedback",
        "autorun",     "Start with Windows",
        "language",    "Language",
        "github",      "Mic Toggle on GitHub",
        "exit",        "Exit",
        "mic_on",      "Microphone on",
        "mic_off",     "Microphone off",
        "mic_none",    "Microphone not found",
        "hk_prompt",   "Press a new key combination (Esc to cancel):",
        "hk_need_mod", "Add Ctrl, Alt, Shift or Win",
        "hk_failed",   "This combination can't be used. Please choose another one.",
        "save",        "Save",
        "cancel",      "Cancel"),
    "ru", Map(
        "mute",        "Выключить микрофон",
        "unmute",      "Включить микрофон",
        "microphone",  "Микрофон",
        "default_mic", "Системный по умолчанию",
        "hotkey",      "Сочетание клавиш: ",
        "beep",        "Звуковые сигналы",
        "autorun",     "Запускать вместе с Windows",
        "language",    "Язык",
        "github",      "Mic Toggle на GitHub",
        "exit",        "Выход",
        "mic_on",      "Микрофон включён",
        "mic_off",     "Микрофон выключен",
        "mic_none",    "Микрофон не найден",
        "hk_prompt",   "Нажмите новое сочетание клавиш (Esc — отмена):",
        "hk_need_mod", "Добавьте Ctrl, Alt, Shift или Win",
        "hk_failed",   "Это сочетание нельзя назначить, выберите другое.",
        "save",        "Сохранить",
        "cancel",      "Отмена"))
LANGUAGES := Map("en", "English", "ru", "Русский")

T(key) => STRINGS[Lang][key]

; ================= Startup =================
MigrateMicSetting()
RepairStartupShortcut()

try Hotkey(HK, ToggleMic, "On")
catch {
    HK := DEFAULT_HK
    Hotkey(HK, ToggleMic, "On")
}

MicMenu := Menu()
BuildTrayMenu()
OnMessage(0x404, TrayNotify)    ; refresh the microphone list when the menu opens
Refresh()
SetTimer(() => Refresh(), 1000) ; picks up mute changes made elsewhere and device changes

; Versions before device IDs stored the microphone by name: look it up once and switch to its ID
MigrateMicSetting() {
    global MicId, MicLabel
    old := IniRead(INI, "main", "mic", "")
    if (old = "" || MicId != "")
        return
    for dev in CaptureDevices() {
        if (dev.name = old) {
            SaveMic(dev.id, dev.name)
            return
        }
    }
}

SaveMic(id, name) {
    global MicId, MicLabel
    MicId := id, MicLabel := name
    IniWrite(id, INI, "main", "mic_id")
    IniWrite(name, INI, "main", "mic_name")
    try IniDelete(INI, "main", "mic")
}

; ================= Tray menu =================
BuildTrayMenu() {
    m := A_TrayMenu
    m.Delete()
    ; the first item's label follows the microphone state, see UpdateToggleItem()
    m.Add(T("mute"), (*) => ToggleMic())
    m.Default := "1&"
    m.ClickCount := 1              ; a single click on the icon toggles the microphone
    m.Add()
    m.Add(T("microphone"), MicMenu)
    m.Add(HotkeyItem(HK), ShowHotkeyDialog)
    m.Add(T("beep"), ToggleBeep)
    m.Add(T("autorun"), ToggleAutorun)

    langMenu := Menu()
    for code, name in LANGUAGES
        langMenu.Add(name, PickLanguage.Bind(code))
    langMenu.Check(LANGUAGES[Lang])
    m.Add(T("language"), langMenu)

    m.Add()
    m.Add(T("github"), (*) => Run(REPO_URL))
    m.Add(T("exit"), (*) => ExitApp())

    if BeepOn
        m.Check(T("beep"))
    if FileExist(STARTUP_LNK)
        m.Check(T("autorun"))
    BuildMicMenu()
}

BuildMicMenu() {
    MicMenu.Delete()
    MicMenu.Add(T("default_mic"), PickMic.Bind("", ""))
    MicMenu.Add()
    used := Map()
    used.CaseSense := "Off"
    checked := T("default_mic")
    found := false
    for dev in CaptureDevices() {
        label := UniqueLabel(dev.name, used)
        MicMenu.Add(label, PickMic.Bind(dev.id, dev.name))
        if (dev.id = MicId) {
            checked := label
            found := true
        }
    }
    ; the selected microphone is not connected right now: show it greyed out
    if (MicId != "" && !found) {
        label := UniqueLabel(MicLabel != "" ? MicLabel : MicId, used)
        MicMenu.Add(label, PickMic.Bind(MicId, MicLabel))
        MicMenu.Disable(label)
        checked := label
    }
    MicMenu.Check(checked)
}

; Menu item names must be unique: identical devices get "(2)", "(3)"...; "&" is escaped
UniqueLabel(name, used) {
    base := StrReplace(name, "&", "&&")
    label := base, n := 1
    while (used.Has(label) || label = T("default_mic"))
        label := base " (" (++n) ")"
    used[label] := true
    return label
}

TrayNotify(wParam, lParam, *) {
    if (lParam & 0xFFFF) = 0x204   ; WM_RBUTTONDOWN
        BuildMicMenu()
}

PickMic(id, name, *) {
    SaveMic(id, name)
    Refresh()
}

PickLanguage(code, *) {
    IniWrite(code, INI, "main", "lang")
    Reload()
}

ToggleBeep(name, *) {
    global BeepOn
    BeepOn := !BeepOn
    IniWrite(BeepOn ? 1 : 0, INI, "main", "beep")
    BeepOn ? A_TrayMenu.Check(name) : A_TrayMenu.Uncheck(name)
}

ToggleAutorun(name, *) {
    if FileExist(STARTUP_LNK) {
        FileDelete(STARTUP_LNK)
        A_TrayMenu.Uncheck(name)
    } else {
        CreateStartupShortcut()
        A_TrayMenu.Check(name)
    }
}

ShortcutTarget() => A_IsCompiled ? A_ScriptFullPath : A_AhkPath
ShortcutArgs()   => A_IsCompiled ? "" : '"' A_ScriptFullPath '"'

CreateStartupShortcut() {
    FileCreateShortcut(ShortcutTarget(), STARTUP_LNK, A_ScriptDir, ShortcutArgs())
}

; If the app was moved after autostart was enabled, point the shortcut to the new location
RepairStartupShortcut() {
    if !FileExist(STARTUP_LNK)
        return
    try {
        FileGetShortcut(STARTUP_LNK, &target, , &args)
        if (target != ShortcutTarget() || args != ShortcutArgs())
            CreateStartupShortcut()
    }
}

; ================= Hotkey =================
ShowHotkeyDialog(*) {
    global HkGui
    if HkGui {
        HkGui.Show()
        return
    }
    try Hotkey(HK, "Off")   ; so the current hotkey doesn't fire while typing a new one

    newKeys := ""
    done := true   ; a full combination is entered; held modifiers won't overwrite it
    HkGui := Gui("+AlwaysOnTop -MinimizeBox", APP_NAME)
    HkGui.SetFont("s10")
    HkGui.Add("Text", , T("hk_prompt"))
    label := HkGui.Add("Text", "w260 h28 Center Border 0x200", HotkeyText(HK))
    HkGui.Add("Button", "w125", T("save")).OnEvent("Click", Save)
    HkGui.Add("Button", "x+10 w125", T("cancel")).OnEvent("Click", Cancel)
    HkGui.OnEvent("Close", Cancel)

    ; capture keys by virtual-key code, not by character, so any keyboard layout works
    ih := InputHook("L0")
    ih.KeyOpt("{All}", "NS")
    ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-S")
    ih.OnKeyDown := OnKey
    ih.OnKeyUp := OnKeyRelease
    ih.Start()
    HkGui.Show()

    OnKey(hook, vk, sc) {
        if IsModifierVK(vk) {   ; show held modifiers live
            done := false
            label.Text := ModsText(HeldMods()) "…"
            return
        }
        if (vk = 0x1B) {   ; Esc
            Cancel()
            return
        }
        mods := ""
        if GetKeyState("Ctrl", "P")
            mods .= "^"
        if GetKeyState("Alt", "P")
            mods .= "!"
        if GetKeyState("Shift", "P")
            mods .= "+"
        if (GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) {
            mods .= "#"
            Send("{Blind}{vkE8}")   ; keep the Start menu from opening after Win is released
        }
        if (mods = "" && !(vk >= 0x70 && vk <= 0x87)) {   ; without a modifier only F1-F24 are allowed
            label.Text := T("hk_need_mod")
            return
        }
        newKeys := mods Format("vk{:02X}", vk)
        label.Text := HotkeyText(newKeys)
        done := true
    }
    OnKeyRelease(hook, vk, sc) {
        if (done || !IsModifierVK(vk))
            return
        held := HeldMods(vk)
        label.Text := held != "" ? ModsText(held) "…" : HotkeyText(newKeys != "" ? newKeys : HK)
    }
    Save(*) {
        if (newKeys = "") {
            Cancel()
            return
        }
        if SetHotkey(newKeys)
            Finish()
    }
    Cancel(*) {
        try Hotkey(HK, "On")
        Finish()
    }
    Finish() {
        ih.Stop()
        CloseDialog()
    }
}

; held modifiers in AutoHotkey notation (^!+#), excluding the key just released
HeldMods(releasedVK := 0) {
    groups := [["^", "Ctrl",  [0x11, 0xA2, 0xA3]]
             , ["!", "Alt",   [0x12, 0xA4, 0xA5]]
             , ["+", "Shift", [0x10, 0xA0, 0xA1]]
             , ["#", "LWin",  [0x5B, 0x5C]]]
    mods := ""
    for g in groups {
        released := false
        for v in g[3]
            if (v = releasedVK)
                released := true
        down := (g[1] = "#") ? (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
                             : GetKeyState(g[2], "P")
        if (down && !released)
            mods .= g[1]
    }
    return mods
}

ModsText(mods) {
    names := Map("^", "Ctrl", "!", "Alt", "+", "Shift", "#", "Win")
    text := ""
    loop parse mods
        text .= names[A_LoopField] "+"
    return text
}

IsModifierVK(vk) {
    return (vk >= 0x10 && vk <= 0x12) || (vk >= 0xA0 && vk <= 0xA5) || vk = 0x5B || vk = 0x5C
}

CloseDialog() {
    global HkGui
    HkGui.Destroy()
    HkGui := 0
}

SetHotkey(keys) {
    global HK
    try Hotkey(keys, ToggleMic, "On")
    catch {
        MsgBox(T("hk_failed"), APP_NAME, "Icon!")
        return false
    }
    if (keys != HK)
        try Hotkey(HK, "Off")
    A_TrayMenu.Rename(HotkeyItem(HK), HotkeyItem(keys))
    HK := keys
    IniWrite(keys, INI, "main", "hotkey")
    return true
}

HotkeyItem(keys) => T("hotkey") HotkeyText(keys) "…"

HotkeyText(keys) {
    mods := Map("^", "Ctrl", "!", "Alt", "+", "Shift", "#", "Win")
    text := ""
    while (StrLen(keys) > 1 && mods.Has(SubStr(keys, 1, 1))) {
        text .= mods[SubStr(keys, 1, 1)] "+"
        keys := SubStr(keys, 2)
    }
    if RegExMatch(keys, "i)^vk([0-9a-f]{1,2})$", &m) {
        vk := Integer("0x" m[1])
        if ((vk >= 0x30 && vk <= 0x39) || (vk >= 0x41 && vk <= 0x5A))
            keys := Chr(vk)   ; letters and digits are always shown in Latin
        else
            keys := GetKeyName("vk" m[1])
    }
    return text StrUpper(keys)
}

; ================= Microphone =================
ToggleMic(*) {
    ids := TargetIds()
    muted := ids.Length ? GetMute(ids[1]) : -1
    if (muted = -1) {
        if BeepOn
            SoundBeep(300, 300)
        return
    }
    for id in ids
        SetMute(id, !muted)
    Refresh(true)
}

Refresh(beep := false) {
    global LastKey
    ids := TargetIds()
    muted := ids.Length ? GetMute(ids[1]) : -1
    state := (muted = -1) ? "none" : muted ? "off" : "on"

    key := state
    for id in ids
        key .= "|" id
    if (key != LastKey) {
        TraySetIcon(state = "on" ? ICON_ON : ICON_OFF)
        A_IconTip := APP_NAME "`n" T(state = "on" ? "mic_on" : state = "off" ? "mic_off" : "mic_none")
        UpdateToggleItem(state)
        LastKey := key
    }
    if (beep && BeepOn && state != "none")
        SoundBeep(state = "off" ? 500 : 1000, 150)
}

; First menu item: an action matching the current state, greyed out when there is no microphone
UpdateToggleItem(state) {
    m := A_TrayMenu
    m.Rename("1&", T(state = "on" ? "mute" : state = "off" ? "unmute" : "mic_none"))
    state = "none" ? m.Disable("1&") : m.Enable("1&")
}

; Devices to mute: the selected microphone if it's connected. With "Windows default",
; the default microphone plus the default communications microphone if Windows has a different one.
TargetIds() {
    ids := []
    if (MicId != "") {
        if IsActiveDevice(MicId)
            ids.Push(MicId)
        return ids
    }
    for role in [0, 2] {   ; eConsole, eCommunications
        id := DefaultCaptureId(role)
        if (id != "" && !(ids.Length && ids[1] = id))
            ids.Push(id)
    }
    return ids
}

; ================= Windows Core Audio =================
; Raw vtable calls to IMMDeviceEnumerator, IMMDevice and IAudioEndpointVolume.
; Devices are identified by their endpoint ID, which is unique even when names repeat.
; Every interface pointer is released in `finally`, so a failing driver can't leak them.

DeviceEnumerator() => ComObject("{BCDE0395-E52F-467C-8E3D-C4579291692E}"
                              , "{A95664D2-9614-4F35-A746-DE8DB63617E6}")

; Active capture devices as [{id, name}, ...]
CaptureDevices() {
    list := []
    coll := 0
    try {
        ComCall(3, DeviceEnumerator(), "int", 1, "uint", 1, "ptr*", &coll)   ; EnumAudioEndpoints(eCapture, ACTIVE)
        count := 0
        ComCall(3, coll, "uint*", &count)                                    ; GetCount
        loop count {
            dev := 0
            try {
                ComCall(4, coll, "uint", A_Index - 1, "ptr*", &dev)           ; Item
                list.Push({id: DeviceId(dev), name: DeviceName(dev)})
            } catch {
                ; skip a device the driver fails to describe
            } finally {
                if dev
                    ObjRelease(dev)
            }
        }
    } catch {
        ; no audio service or no devices: return what we have
    } finally {
        if coll
            ObjRelease(coll)
    }
    return list
}

DefaultCaptureId(role) {
    dev := 0
    try {
        ComCall(4, DeviceEnumerator(), "int", 1, "int", role, "ptr*", &dev)  ; GetDefaultAudioEndpoint(eCapture, role)
        return DeviceId(dev)
    } catch {
        return ""
    } finally {
        if dev
            ObjRelease(dev)
    }
}

; IMMDevice pointer for an endpoint ID, or 0. The caller releases it.
OpenDevice(id) {
    dev := 0
    try ComCall(5, DeviceEnumerator(), "wstr", id, "ptr*", &dev)              ; GetDevice
    catch
        return 0
    return dev
}

IsActiveDevice(id) {
    dev := OpenDevice(id)
    if !dev
        return false
    try {
        state := 0
        ComCall(6, dev, "uint*", &state)                                     ; GetState
        return state = 1                                                     ; DEVICE_STATE_ACTIVE
    } catch {
        return false
    } finally {
        ObjRelease(dev)
    }
}

; IAudioEndpointVolume pointer for an endpoint ID, or 0. The caller releases it.
EndpointVolume(id) {
    dev := OpenDevice(id)
    if !dev
        return 0
    epv := 0
    try {
        iid := GuidBuffer("{5CDF2C82-841E-4546-9722-0CF74078229A}")
        ComCall(3, dev, "ptr", iid, "uint", 0x17, "ptr", 0, "ptr*", &epv)    ; Activate(CLSCTX_ALL)
    } catch {
        epv := 0
    } finally {
        ObjRelease(dev)
    }
    return epv
}

; 1 = muted, 0 = not muted, -1 = unavailable
GetMute(id) {
    epv := EndpointVolume(id)
    if !epv
        return -1
    try {
        muted := 0
        ComCall(15, epv, "int*", &muted)                                     ; GetMute
        return muted ? 1 : 0
    } catch {
        return -1
    } finally {
        ObjRelease(epv)
    }
}

SetMute(id, muted) {
    epv := EndpointVolume(id)
    if !epv
        return
    try ComCall(14, epv, "int", muted ? 1 : 0, "ptr", 0)                     ; SetMute
    ObjRelease(epv)
}

DeviceId(dev) {
    ptr := 0
    ComCall(5, dev, "ptr*", &ptr)                                            ; GetId
    id := StrGet(ptr, "UTF-16")
    DllCall("ole32\CoTaskMemFree", "ptr", ptr)
    return id
}

DeviceName(dev) {
    store := 0
    pv := Buffer(24, 0)                                                      ; PROPVARIANT
    try {
        ComCall(4, dev, "uint", 0, "ptr*", &store)                           ; OpenPropertyStore(STGM_READ)
        key := Buffer(20)                                                    ; PKEY_Device_FriendlyName
        DllCall("ole32\CLSIDFromString", "wstr", "{A45C254E-DF1C-4EFD-8020-67D146A850E0}", "ptr", key)
        NumPut("uint", 14, key, 16)
        ComCall(5, store, "ptr", key, "ptr", pv)                             ; GetValue
        ptr := NumGet(pv, 8, "ptr")
        return ptr ? StrGet(ptr, "UTF-16") : ""
    } finally {
        DllCall("ole32\PropVariantClear", "ptr", pv)
        if store
            ObjRelease(store)
    }
}

GuidBuffer(str) {
    buf := Buffer(16)
    DllCall("ole32\CLSIDFromString", "wstr", str, "ptr", buf)
    return buf
}
