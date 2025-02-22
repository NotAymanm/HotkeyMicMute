#NoEnv
#SingleInstance, Force
#Include VA.ahk

OnExit("ExitScript")

; ================= CONFIGURATION =================
padding := 40                                                   ; Padding from screen edges
muteSfx := "C:\Windows\Media\Windows Ding.wav"                  ; Path to mute sound
unmuteSfx := "C:\Windows\Media\Windows Exclamation.wav"         ; Path to unmute sound
imagePath := "muted.png"                                      ; Path to overlay image
; =================================================

; Create GUI for overlay image
Gui, Overlay: +AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x80000

Gui, Overlay: Color, 000000  ; Set background to black
Gui, Overlay: +LastFound  ; Apply transparency to this window
WinSet, TransColor, 000000  ; Make black transparent

Gui, Overlay: Margin, 0, 0
Gui, Overlay: Add, Picture, vOverlayImage, %imagePath%
GuiControlGet, picSize, Overlay: Pos, OverlayImage

; Calculate position
ScreenWidth := A_ScreenWidth
ScreenHeight := A_ScreenHeight
posX := ScreenWidth - picSizeW - padding
posY := ScreenHeight - picSizeH - padding

isMuted := false  ; Track mute state
originalVolumes := {}  ; Store device IDs and their volumes


; ================= HOTKEY ============================
Pause::
    isMuted := !isMuted  ; Toggle state


    Loop {
        ; Try to get each capture device by index
        device_desc := "capture:" A_Index
        device := VA_GetDevice(device_desc)

        ; No more devices found
        if !device
            break

        ; Toggle mute for this device
        VA_SetMasterMute(isMuted, device_desc)

        ; Clean up COM object
        ObjRelease(device)
    }






    if (isMuted) { ; Muting - store volumes and set to 0
        originalVolumes := {}  ; Reset storage
        ; Get all capture devices by ID
        devices := VA_GetDeviceList("capture")

        for index, deviceID in devices {
            ; Get volume through device ID
            vol := VA_GetMasterVolume(, deviceID)
            if (vol != "") {
                originalVolumes[deviceID] := vol
                ; Toggle mute for this device
                VA_SetMasterVolume(0, "", deviceID)
            }
        }
        SoundPlay, % muteSfx
        Gui, Overlay: Show, x%posX% y%posY% NA
    } else { ; Unmuting - restore original volumes
        for deviceID, vol in originalVolumes {
            ; Toggle mute for this device
            VA_SetMasterVolume(vol, "", deviceID)
        }
        originalVolumes := {}  ; Clear storage
        SoundPlay, % unmuteSfx
        Gui, Overlay: Hide
    }

return
; =====================================================




; ================= HELPER FUNCTIONS ==================
; Modified VA.ahk helper function to get device list
VA_GetDeviceList(flow="capture") {
    devices := []
    deviceEnumerator := ComObjCreate("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
    VA_IMMDeviceEnumerator_EnumAudioEndpoints(deviceEnumerator, flow = "capture" ? 1 : 0, 1, deviceCollection)
    VA_IMMDeviceCollection_GetCount(deviceCollection, count)

    Loop % count {
        VA_IMMDeviceCollection_Item(deviceCollection, A_Index-1, device)
        VA_IMMDevice_GetId(device, deviceID)
        devices.Push(deviceID)
        ObjRelease(device)
    }

    ObjRelease(deviceCollection)
    ObjRelease(deviceEnumerator)
    return devices
}
; ====================================================


; ================= EXIT FUNCTION =================
ExitScript() {
    global isMuted, originalVolumes, unmuteSfx

    if (isMuted) {
        for deviceID, vol in originalVolumes {
            VA_SetMasterVolume(vol, "", deviceID)
        }

        ; Unmute all capture devices
        devices := VA_GetDeviceList("capture")
        for index, deviceID in devices {
            VA_SetMasterMute(false, deviceID)  ; Set mute state to off
        }

        SoundPlay, % unmuteSfx
    }
    Gui, Overlay: Destroy
    
    ExitApp ; Ensure script terminates
}
; =================================================