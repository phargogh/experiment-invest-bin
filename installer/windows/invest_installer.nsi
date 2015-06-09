; Variables needed at the command line:
; VERSION         - the version of InVEST we're building (example: 3.4.5)
; VERSION_DISK    - the windows-safe version of InVEST we're building
;                   This needs to be a valid filename on windows (no : , etc),
;                   but could represent a development build.
; INVEST_3_FOLDER - The local folder of binaries to include.
; SHORT_VERSION   - The short version name.  Usually a tagname such as 'tip',
;                   'default', or 3.4.5.
; ARCHITECTURE    - The architecture we're building for.  Generally this is x86.

!include nsProcess.nsh
!include LogicLib.nsh
; HM NIS Edit Wizard helper defines
!define PRODUCT_NAME "InVEST"
!define PRODUCT_VERSION "${VERSION} ${ARCHITECTURE}"
!define PDF_NAME "InVEST_${SHORT_VERSION}_Documentation.pdf"
!define PRODUCT_PUBLISHER "The Natural Capital Project"
!define PRODUCT_WEB_SITE "http://www.naturalcapitalproject.org"
!define MUI_COMPONENTSPAGE_NODESC
!define PACKAGE_NAME "${PRODUCT_NAME} ${PRODUCT_VERSION}"

SetCompressor /FINAL /SOLID lzma
SetCompressorDictSize 64

; MUI has some graphical files that I want to define, which must be defined
; here before the macros are declared.
!define MUI_WELCOMEFINISHPAGE_BITMAP "InVEST-vertical.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "InVEST-vertical.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "InVEST-header-wcvi-rocks.bmp"
!define MUI_UNHEADERIMAGE_BITMAP "InVEST-header-wcvi-rocks.bmp"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\orange-uninstall.ico"

; MUI 1.67 compatible ------
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"
!include "nsDialogs.nsh"

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "InVEST-2.ico"

; Add an advanced options control for the welcome page.
!define MUI_PAGE_CUSTOMFUNCTION_SHOW AddAdvancedOptions
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE ValidateAdvZipFile
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "license.rtf"

!define MUI_PAGE_CUSTOMFUNCTION_PRE SkipComponents
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
;!define MUI_FINISHPAGE_SHOWREADME ${PDF_NAME}
!insertmacro MUI_PAGE_FINISH

; MUI Uninstaller settings---------------
!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

; Language files
!insertmacro MUI_LANGUAGE "English"

; MUI end ------

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "InVEST_${VERSION_DISK}_${ARCHITECTURE}_Setup.exe"
InstallDir "C:\InVEST_${VERSION_DISK}_${ARCHITECTURE}"
ShowInstDetails show

; This function allows us to test to see if a process is currently running.
; If the process name passed in is actually found, a message box is presented
; and the uninstaller should quit.
!macro CheckProgramRunning process_name
    ${nsProcess::FindProcess} "${process_name}.exe" $R0
    Pop $R0

    StrCmp $R0 603 +3
        MessageBox MB_OK|MB_ICONEXCLAMATION "The model ${process_name} is still running.  Please close all InVEST models and try again."
        Abort
!macroend

var AdvCheckbox
var AdvFileField
var AdvZipFile
var LocalDataZipFile
Function AddAdvancedOptions
    ${NSD_CreateCheckBox} 120u -18u 15% 12u "Advanced"
    pop $AdvCheckbox
    ${NSD_OnClick} $AdvCheckbox EnableAdvFileSelect

    ${NSD_CreateFileRequest} 175u -18u 36% 12u ""
    pop $AdvFileField
    ShowWindow $AdvFileField 0

    ${NSD_CreateBrowseButton} 300u -18u 5% 12u "..."
    pop $AdvZipFile
    ${NSD_OnClick} $AdvZipFile GetZipFile
    ShowWindow $AdvZipFile 0
FunctionEnd

Function EnableAdvFileSelect
    ${NSD_GetState} $AdvCheckbox $0
    ShowWindow $AdvFileField $0
    ShowWindow $AdvZipFile $0
FunctionEnd

Function GetZipFile
    nsDialogs::SelectFileDialog "open" "" "Zipfiles *.zip"
    pop $0
    ${GetFileExt} $0 $1
    ${If} "$1" != "zip"
        MessageBox MB_OK "File must be a zipfile"
        Abort
    ${EndIf}
    ${NSD_SetText} $AdvFileField $0
    strcpy $LocalDataZipFile $0
FunctionEnd

Function SkipComponents
    ${If} $LocalDataZipFile != ""
        Abort
    ${EndIf}
FunctionEnd

Function ValidateAdvZipFile
    ${NSD_GetText} $AdvFileField $0
    ${If} $0 != ""
        ${GetFileExt} $1 $0
        ${If} $1 != "zip"
            MessageBox MB_OK "File must be a zipfile"
        ${EndIf}
    ${Else}
        strcpy $LocalDataZipFile $0
    ${EndIf}
FunctionEnd

!define LVM_GETITEMCOUNT 0x1004
!define LVM_GETITEMTEXT 0x102D

Function DumpLog
    Exch $5
    Push $0
    Push $1
    Push $2
    Push $3
    Push $4
    Push $6

    FindWindow $0 "#32770" "" $HWNDPARENT
    GetDlgItem $0 $0 1016
    StrCmp $0 0 exit
    FileOpen $5 $5 "w"
    StrCmp $5 "" exit
        SendMessage $0 ${LVM_GETITEMCOUNT} 0 0 $6
        System::Alloc ${NSIS_MAX_STRLEN}
        Pop $3
        StrCpy $2 0
        System::Call "*(i, i, i, i, i, i, i, i, i) i \
            (0, 0, 0, 0, 0, r3, ${NSIS_MAX_STRLEN}) .r1"
        loop: StrCmp $2 $6 done
            System::Call "User32::SendMessageA(i, i, i, i) i \
            ($0, ${LVM_GETITEMTEXT}, $2, r1)"
            System::Call "*$3(&t${NSIS_MAX_STRLEN} .r4)"
            FileWrite $5 "$4$\r$\n"
            IntOp $2 $2 + 1
            Goto loop
        done:
            FileClose $5
            System::Free $1
            System::Free $3
    exit:
        Pop $6
        Pop $4
        Pop $3
        Pop $2
        Pop $1
        Pop $0
        Exch $5
FunctionEnd

Function .onInit
 System::Call 'kernel32::CreateMutexA(i 0, i 0, t "InVEST ${VERSION}") i .r1 ?e'
 Pop $R0

 StrCmp $R0 0 +3
   MessageBox MB_OK|MB_ICONEXCLAMATION "An InVEST ${VERSION} installer is already running."
   Abort
FunctionEnd

Function Un.onInit

    !insertmacro CheckProgramRunning "invest_habitat_quality"
    !insertmacro CheckProgramRunning "invest_carbon"
    !insertmacro CheckProgramRunning "invest_pollination"
    !insertmacro CheckProgramRunning "invest_timber"
    !insertmacro CheckProgramRunning "invest_finfish_aquaculture"
    !insertmacro CheckProgramRunning "invest_marine_water_quality_biophysical"
    !insertmacro CheckProgramRunning "invest_overlap_analysis_mz"
    !insertmacro CheckProgramRunning "invest_overlap_analysis"
    !insertmacro CheckProgramRunning "invest_wave_energy"
    !insertmacro CheckProgramRunning "invest_water_scarcity"
    !insertmacro CheckProgramRunning "invest_water_yield"
    !insertmacro CheckProgramRunning "invest_hyropower_valuation"
FunctionEnd

Section "InVEST Tools and ArcGIS toolbox" Section_InVEST_Tools
  SetShellVarContext all
  SectionIn RO ;require this section

  !define SMPATH "$SMPROGRAMS\${PACKAGE_NAME}"
  !define INVEST_ICON "$INSTDIR\${INVEST_3_FOLDER}\installer\InVEST-2.ico"
  !define INVEST_DATA "$INSTDIR\${INVEST_3_FOLDER}"
  !define RECREATION "${SMPATH}\Recreation"
  !define OVERLAP "${SMPATH}\Overlap Analysis"
  !define HRA "${SMPATH}\Habitat Risk Assessment"
  !define BLUECARBON "${SMPATH}\Blue Carbon"
  !define FISHERIES "${SMPATH}\Fisheries"
  !define HYDROPOWER "${SMPATH}\Hydropower"

  ; Write the uninstaller to disk
  SetOutPath "$INSTDIR"
  !define UNINSTALL_PATH "$INSTDIR\Uninstall_${VERSION_DISK}.exe"
  writeUninstaller "${UNINSTALL_PATH}"

  ; Create start  menu shortcuts.
  ; These shortcut paths are set in the appropriate places based on the SetShellVarConext flag.
  ; This flag is automatically set based on the MULTIUSER installation mode selected by the user.
  SetOutPath "$INSTDIR\${INVEST_3_FOLDER}"

  CreateDirectory "${SMPATH}"
  CreateShortCut "${SMPATH}\Crop Production (unstable) (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_crop_production.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\Scenic Quality (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_scenic_quality.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\Habitat Quality (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_habitat_quality.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\Carbon (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_carbon.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\Pollination (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_pollination.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\Timber (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_timber.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\Finfish Aquaculture (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_finfish_aquaculture.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\Marine Water Quality (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_marine_water_quality_biophysical.exe" "" "${INVEST_ICON}"
  CreateDirectory "${OVERLAP}"
  CreateShortCut "${OVERLAP}\Overlap Analysis (Management Zones) (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_overlap_analysis_mz.exe" "" "${INVEST_ICON}"
  CreateShortCut "${OVERLAP}\Overlap Analysis (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_overlap_analysis.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\Wave Energy (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_wave_energy.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\Wind Energy (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_wind_energy.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\Coastal Vulnerability (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_coastal_vulnerability.exe" "" "${INVEST_ICON}"

  CreateDirectory "${BLUECARBON}"
  CreateShortCut "${BLUECARBON}\(1) Blue Carbon Preprocessor (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_blue_carbon_preprocessor.exe" "" "${INVEST_ICON}"
  CreateShortCut "${BLUECARBON}\(2) Blue Carbon Calculator (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_blue_carbon.exe" "" "${INVEST_ICON}"

  CreateDirectory "${FISHERIES}"
  CreateShortCut "${FISHERIES}\(1) Fisheries (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_fisheries.exe" "" "${INVEST_ICON}"
  CreateShortCut "${FISHERIES}\(2) Fisheries Habitat Scenario Tool (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_fisheries_hst.exe" "" "${INVEST_ICON}"

  CreateDirectory "${HRA}"
  CreateShortCut "${HRA}\(1) Habitat Risk Assessment Preprocessor (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_hra_preprocessor.exe" "" "${INVEST_ICON}"
  CreateShortCut "${HRA}\(2) Habitat Risk Assessment (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_hra.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\SDR (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_sdr.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\Nutrient Retention (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_nutrient.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\Scenario Generator (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_scenario_generator.exe" "" "${INVEST_ICON}"

  CreateShortCut "${SMPATH}\Water Yield (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_hydropower_water_yield.exe" "" "${INVEST_ICON}"

  CreateShortCut "${SMPATH}\RouteDEM (${ARCHITECTURE}).lnk" "${INVEST_DATA}\routedem.exe" "" "${INVEST_ICON}"
  CreateShortCut "${SMPATH}\DelineateIt (${ARCHITECTURE}).lnk" "${INVEST_DATA}\delineateit.exe" "" "${INVEST_ICON}"

  CreateDirectory "${RECREATION}"
  CreateShortCut "${RECREATION}\(1) Recreation Initialization (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_recreation_client_init.exe" "" "${INVEST_ICON}"
  CreateShortCut "${RECREATION}\(2) Recreation Scenario (${ARCHITECTURE}).lnk" "${INVEST_DATA}\invest_recreation_client_scenario.exe" "" "${INVEST_ICON}"

  ; Write registry keys for convenient uninstallation via add/remove programs.
  ; Inspired by the example at
  ; nsis.sourceforge.net/A_simple_installer_with_start_menu_shortcut_and_uninstaller
  !define REGISTRY_PATH "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_PUBLISHER} ${PRODUCT_NAME} ${PRODUCT_VERSION}"
  WriteRegStr HKLM "${REGISTRY_PATH}" "DisplayName"          "${PRODUCT_NAME} ${PRODUCT_VERSION}"
  WriteRegStr HKLM "${REGISTRY_PATH}" "UninstallString"      "${UNINSTALL_PATH}"
  WriteRegStr HKLM "${REGISTRY_PATH}" "QuietUninstallString" "${UNINSTALL_PATH} /S"
  WriteRegStr HKLM "${REGISTRY_PATH}" "InstallLocation"      "$INSTDIR"
  WriteRegStr HKLM "${REGISTRY_PATH}" "DisplayIcon"          "${INVEST_ICON}"
  WriteRegStr HKLM "${REGISTRY_PATH}" "Publisher"            "${PRODUCT_PUBLISHER}"
  WriteRegStr HKLM "${REGISTRY_PATH}" "URLInfoAbout"         "${PRODUCT_WEB_SITE}"
  WriteRegStr HKLM "${REGISTRY_PATH}" "DisplayVersion"       "${PRODUCT_VERSION}"
  WriteRegDWORD HKLM "${REGISTRY_PATH}" "NoModify" 1
  WriteRegDWORD HKLM "${REGISTRY_PATH}" "NoRepair" 1


  ; Actually install the information we want to disk.
  SetOutPath "$INSTDIR"
  File license.txt
  File ..\invest-natcap\*.tbx
  File ..\invest-natcap\docs\release_notes\*.txt
  File /nonfatal ..\invest-natcap.users-guide\build\latex\${PDF_NAME}

  SetOutPath "$INSTDIR\invest_helper_utils\"
  File /r /x *.hg* /x *.svn* ..\invest-natcap\utils\*

  SetOutPath "$INSTDIR\python\"
  File /r /x *.hg* /x *.svn* ..\invest-natcap\python\*

  SetOutPath "$INSTDIR\${INVEST_3_FOLDER}\"
  File /r /x *.hg* /x *.svn* ..\${INVEST_3_FOLDER}\*

;  SetOutPath "$INSTDIR\${INVEST_3_FOLDER_x64}\"
;  File /r /x *.hg* /x *.svn* ..\${INVEST_3_FOLDER_x64}\*

  SetOutPath "$INSTDIR\documentation"
  File /r /x *.hg* /x *.svn* ..\invest-natcap.users-guide\build\html\*

  ; If the user has provided a custom data zipfile, unzip the data.
  ${If} $LocalDataZipFile != ""
    nsisunz::UnzipToLog "$LocalDataZipFile" "$INSTDIR"
  ${EndIf}

  ; Write the install log to a text file on disk.
  StrCpy $0 "$INSTDIR\install_log.txt"
  Push $0
  Call DumpLog

SectionEnd

Section "uninstall"
  ; Need to enforce execution level as admin.  See
  ; nsis.sourceforge.net/Shortcuts_removal_fails_on_Windows_Vista
  SetShellVarContext all
  rmdir /r "$SMPROGRAMS\${PACKAGE_NAME}"

  ; Delete the installation directory on disk
  rmdir /r "$INSTDIR"

  ; Delete the entire registry key for this version of RIOS.
  DeleteRegKey HKLM "${REGISTRY_PATH}"
SectionEnd

Var SERVER_PATH
Var LocalDataZip
Var INSTALLER_DIR

!macro downloadData Title Filename AdditionalSize
  Section "${Title}"
    AddSize "${AdditionalSize}"

    ; Check to see if the user defined an 'advanced options' zipfile.
    ; If yes, then we should skip all of this checking, since we only want to use
    ; the data that was in that zip.
    ${If} $LocalDataZipFile != ""
        goto end_of_section
    ${EndIf}

    ${GetExePath} $INSTALLER_DIR
    StrCpy $LocalDataZip "$INSTALLER_DIR\sample_data\${Filename}"
;    MessageBox MB_OK "zip: $LocalDataZip"
    IfFileExists "$LocalDataZip" LocalFileExists DownloadFile
    LocalFileExists:
        nsisunz::UnzipToLog "$LocalDataZip" "$INSTDIR"
;        MessageBox MB_OK "found it locally"
       goto done
    DownloadFile:
        ;This is hard coded so that all the download data macros go to the same site
        StrCpy $SERVER_PATH "http://data.naturalcapitalproject.org/~dataportal/invest-data/${SHORT_VERSION}"
        SetOutPath "$INSTDIR"
        NSISdl::download "$SERVER_PATH/${Filename}" ${Filename}
        Pop $R0 ;Get the status of the file downloaded
        StrCmp $R0 "success" got_it failed
        got_it:
           nsisunz::UnzipToLog ${Filename} "."
           Delete ${Filename}
           goto done
        failed:
           MessageBox MB_OK "Download failed: $R0 $SERVER_PATH/${Filename}. This might have happened because your Internet connection timed out, or our download server is experiencing problems.  The installation will continue normally, but you'll be missing the ${Filename} dataset in your installation.  You can manually download that later by visiting the 'Individual inVEST demo datasets' section of our download page at www.naturalcapitalproject.org."
  done:
      ; Write the install log to a text file on disk.
      StrCpy $0 "$INSTDIR\install_data_${Title}_log.txt"
      Push $0
      Call DumpLog
      end_of_section:
      SectionEnd
!macroend

SectionGroup /e "InVEST Datasets" SEC_DATA
  ;here all the numbers indicate the size of the downloads in kilobytes
  ;they were calculated by hand by decompressing all the .zip files and recording
  ;the size by hand.
  SectionGroup "Freshwater Datasets" SEC_FRESHWATER_DATA
    !insertmacro downloadData "Freshwater base datasets (optional for freshwater models)" "Freshwater.zip" 4710
    !insertmacro downloadData "Hydropower (optional)" "Hydropower.zip" 100
    !insertmacro downloadData "Nutrient Retention (required to run model)" "WP_Nutrient_Retention.zip" 4
    !insertmacro downloadData "SDR (required to run model)" "Sedimentation.zip" 4
  SectionGroupEnd

  SectionGroup "Marine Datasets" SEC_MARINE_DATA
    !insertmacro downloadData "Marine base datasets (required for many marine models)" "Marine.zip" 1784696
    !insertmacro downloadData "Aquaculture (optional)" "Aquaculture.zip" 856
    !insertmacro downloadData "Blue Carbon (optional)" "BlueCarbon.zip" 856
    !insertmacro downloadData "Coastal protection (optional)" "CoastalProtection.zip" 117760
    !insertmacro downloadData "Fisheries (optional)" "Fisheries.zip" 784
    !insertmacro downloadData "Habitat risk assessment (optional)" "HabitatRiskAssess.zip" 8116
    !insertmacro downloadData "Marine Water Quality (optional)" "MarineWaterQuality.zip" 13312
    !insertmacro downloadData "Overlap analysis (optional)" "OverlapAnalysis.zip" 3692
    !insertmacro downloadData "Scenic quality (optional)" "ScenicQuality.zip" 9421
    !insertmacro downloadData "Wave Energy (required to run model)" "WaveEnergy.zip" 831620
    !insertmacro downloadData "Wind Energy (required to run model)" "WindEnergy.zip" 4804
    !insertmacro downloadData "Recreation (optional)" "Recreation.zip" 24
  SectionGroupEnd

  SectionGroup "Terrestrial Datasets" SEC_TERRESTRIAL_DATA
    !insertmacro downloadData "CropProduction (optional)" "CropProduction.zip" 0
    !insertmacro downloadData "GLOBIO (optional)" "globio.zip" 0
    !insertmacro downloadData "Terrestrial base datasets (optional for many terrestrial)" "Terrestrial.zip" 587776
    !insertmacro downloadData "Habitat Quality (optional)" "HabitatQuality.zip" 160768
    !insertmacro downloadData "Carbon (optional)" "Carbon.zip" 728
    !insertmacro downloadData "Pollination (optional)" "Pollination.zip" 176
    !insertmacro downloadData "Timber (optional)" "Timber.zip" 644
    !insertmacro downloadData "Scenario Generator (optional)" "ScenarioGenerator.zip" 0
  SectionGroupEnd
SectionGroupEnd
