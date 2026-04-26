#=======================================================
# Mod Selection
#=======================================================

#This is the name of the mod you want to make to better distinguish versions for different mods, e.g storyteller_vanilla, $storyteller_anbennar_steam, storyteller_meiou etc
#$modName = "storyteller_vanilla"
#$modName = "storyteller_anbennar_steam"
$modName = "storyteller_anbennar_gitlab"     #I use anbennar as an example to show the difference between vanilla and any mod

#This needs to point at the root directory of either the base game if you want to do vanilla, or the root folder of the mod if you want to do any mod
#$rootFolder = "D:\Steam\steamapps\common\Europa Universalis IV"                                         #EU 4 Vanilla
#$rootFolder = "D:\Steam\steamapps\workshop\content\236850\1385440355"                                   #Anbennar Steam version
$rootFolder = "C:\Users\grand\Documents\Paradox Interactive\Europa Universalis IV\mod\Anbennar-PublicFork"       #Anbennar GitLab Version

#Your EU4 mod folder
$modFolder = "C:\Users\grand\Documents\Paradox Interactive\Europa Universalis IV\mod"


#=======================================================
# Script Folder Configuration
#=======================================================

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$localisationFolder = [System.IO.Path]::Combine($rootFolder, "localisation")
$eventsFolder = [System.IO.Path]::Combine($rootFolder, "events")
$eventDescFolder = [System.IO.Path]::Combine($scriptFolder, "eventdescriptions", $modName)
$modOutputFolder = [System.IO.Path]::Combine($scriptFolder, "build", $modName)
$soundFolder = [System.IO.Path]::Combine($modOutputFolder, "sound")
$alteredEventsFolder = [System.IO.Path]::Combine($modOutputFolder, "events")
$customGuiFolder = [System.IO.Path]::Combine($modOutputFolder, "common", "custom_gui")

$csvFile = [System.IO.Path]::Combine($scriptFolder, "filelist_$modName.csv")
$assetFile = [System.IO.Path]::Combine($soundFolder, "$modName.asset")
$customGuiFile = [System.IO.Path]::Combine($customGuiFolder, "$modName.txt")


#=======================================================
# vLLM Configuration 
#=======================================================
$vllmApiUrl = "http://127.0.0.1:8000/v1/chat/completions"
$vllmModel = "google/gemma-4-E4B-it"

$llmPrompt = @"
!!!THE MOST IMPORTANT INSTRUCTION IS TO ENSURE NO DYNAMIC LOC REMAINS, NOT A SINGLE BRACKET OR DOLLAR SIGN IN THE ANSWER!!!

You are a text-cleaning script preparing text for a Text-to-Speech engine. 
The user will provide event text from Europa Universalis IV that contains dynamic variables enclosed in brackets [] or dollar signs $. 

Events are started either by a country, or by a single province of a country. Sometimes events will have impact on other countries or provinces, which then also have an event triggered.
ROOT refers to the country or province that is currently being evaluated for events firing, FROM denotes another country or province that somehow has effected the current ROOT being evaluated. 
Therefore, from a first person perspective, ROOT is usually our nation or province, while FROM is usually some other province or nation, HOWEVER: Since the player reads these events as the spirit of the nation, an event started by one of our provinces would often be better treated as "them" rather than "us". 

For example, if the event is triggered by a province and refers to the provinces religion via [Root.Religion.GetName], and the context of the sentence is mostly negative (for example the [Root.Religion.GetName] fools of [Root.GetName] almost certainly means that this is a province event and that we view the religion in that province as heretical. So despite being our province, the event is more about "them". 

Try to decipher what exactly might be going on from the context of the entire event text. There are also other special scopes, for example for the country which is currently holding the mandate of heaven (empire_of_china). Often it can be inferred what a scope is supposed to represent by how that scope is called.



Execute the following rules strictly:
1. REPLACE ALL TAGS: Replace all dynamic variables (e.g., [Root.Monarch.GetName], $COUNTRY$, EVERYTHING between brackets or dollar signs) with generic, natural-sounding spoken words based on context. If you are unable to determine the context by reading the entire sentence, you can also remove the dynamic loc tag entirely, but only if the sentence still makes sense after the removal. If additional (non dynamic loc) words must be changed for the replacement word to make sense, you may do so, but only do this to ensure the sentence makes sense, do not change other words randomly. Overall, just ensure that no dynamic loc remains while trying to keep as faithfully to the original text as possible. FROM THE CONTEXT OF THE ENTIRE SENTENCE, DECIDE ON WETHER THE EVENT IS A COUNTRY OR A PROVINCE EVENT AND MAKE LOC REPLACEMENTS ACCORDINGLY.
2. CONTEXTUAL RULES:
   - Often the dynamic loc hints at what it is supposed to be via it's name, ie $ADM_Advisor$ would be our administrative advisor or [empire_of_china.GetAdjective] would be the adjective of whichever country currently holds the Mandate of Heaven, so a possible substitution that somewhat makes sense no matter the country could be "celestial". 
   - Locations: use "country", "province", "realm", or "domain".
   - Rulers/People: use "lord", "ruler", "monarch", "heir", or "advisor".
   - Pronouns: substitute with "they/their" where appropriate.
   - Dates ([GetDate], [GetYear]): use "today", "now", "currently", or remove entirely if redundant.
3. COMBINE TAGS: If multiple tags appear together (e.g., [Root.Monarch.GetTitle] [Root.Monarch.GetName]), combine them into a single natural phrase.
4. SPELLING & PUNCTUATION: Correct any obvious spelling errors, awkward grammar, or broken punctuation in the base text to ensure the speech engine reads it fluidly.
5. NO LEFTOVERS: Under no circumstances should any brackets [], dollar signs $, or placeholder variable names remain in the final text. Output ONLY natural, spoken words and standard punctuation.
6. ABSOLUTE CONSTRAINT: You must return ONLY the cleaned, readable text without any further explanations or notes. Do not include any explanations, preambles, or conversational filler or the thinking process.
7. REPLACE ROMAN NUMERALS: Some non dynamic names come with roman numerals, for example Pope Eugene IV. Replace the roman numerals with how it would be read, i.e Pope Eugene the Fourth.
8. ENSURE INTERNAL SENTENCE LOGIC: Make sure that the final sentence is internally logical. So if after replacing the loc the sentence reads like "Our lord is weak, and the people are rising up to support our lord taking over their country.", something clearly is not right.
9. DO NOT USE PLACEHOLDERS YOURSELF, INSTEAD DELETE PARTS OF THE SENTENCE: If a sentence has clarifying sections like "our [dynloc], [dynloc.GetName], has done something..." you can just ignore parts of the sentence and adjust the punctuation accordingly, resulting for example in "our heir has done something..." or "our ruler has done something". Dyn Loc that clearly exists only to clarify the name of the place or person is irrelevant and can be ommitted when convenient. 

!!!THE MOST IMPORTANT INSTRUCTION IS TO ENSURE NO DYNAMIC LOC REMAINS, NOT A SINGLE BRACKET OR DOLLAR SIGN IN THE ANSWER!!!
"@


#=======================================================
# TTS Configuration
#=======================================================

$ttsApiUrl = "http://127.0.0.1:7851/api/tts-generate"


#=======================================================
# Script Code
#=======================================================

Write-Host "Assembling Final Mod Folder..." -ForegroundColor Cyan

# Ensure the specific mod build folder exists
if (-not (Test-Path $modOutputFolder)) {
    New-Item -ItemType Directory -Path $modOutputFolder -Force | Out-Null
}

$bootstrapFolder = [System.IO.Path]::Combine($scriptFolder, "bootstrap")

# 1. Copy Localisation cleanly
$bootstrapLoc = [System.IO.Path]::Combine($bootstrapFolder, "localisation")
$buildLoc = [System.IO.Path]::Combine($modOutputFolder, "localisation")

if (Test-Path $bootstrapLoc) {
    if (-not (Test-Path $buildLoc)) {
        New-Item -ItemType Directory -Path $buildLoc -Force | Out-Null
    }
    Write-Host "Copying localisation files from bootstrap..." -ForegroundColor Yellow
    Copy-Item -Path "$bootstrapLoc\*" -Destination $buildLoc -Recurse -Force
} else {
    Write-Warning "Localisation folder not found in bootstrap."
}

# 2. Handle topbar.gui priority logic
$modInterfaceDir = [System.IO.Path]::Combine($rootFolder, "interface")
$modTopbar = [System.IO.Path]::Combine($modInterfaceDir, "topbar.gui")

$bootstrapInterfaceDir = [System.IO.Path]::Combine($bootstrapFolder, "interface")
$bootstrapTopbar = [System.IO.Path]::Combine($bootstrapInterfaceDir, "topbar.gui")

$buildInterfaceDir = [System.IO.Path]::Combine($modOutputFolder, "interface")

if (-not (Test-Path $buildInterfaceDir)) {
    New-Item -ItemType Directory -Path $buildInterfaceDir -Force | Out-Null
}

if (Test-Path $modTopbar) {
    Write-Host "Found topbar.gui in target mod folder. Using this to preserve mod compatibility." -ForegroundColor Yellow
    Copy-Item -Path $modTopbar -Destination $buildInterfaceDir -Force
} elseif (Test-Path $bootstrapTopbar) {
    Write-Host "No topbar.gui in target mod folder. Falling back to vanilla version from bootstrap." -ForegroundColor Yellow
    Copy-Item -Path $bootstrapTopbar -Destination $buildInterfaceDir -Force
} else {
    Write-Warning "Could not find a topbar.gui file in either the mod folder or the bootstrap/interface folder!"
}

# 3. Inject the Button
$buildTopbar = [System.IO.Path]::Combine($buildInterfaceDir, "topbar.gui")

if (Test-Path $buildTopbar) {
    $topbarContent = Get-Content -Raw $buildTopbar
    
    # Check if logic already added
    if ($topbarContent -match "name\s*=\s*`"?${modName}_playsound`"?") {
        Write-Host "topbar.gui already contains the playsound button." -ForegroundColor Yellow
    } else {
        Write-Host "Injecting UI button into topbar window..." -ForegroundColor Yellow
        $lines = $topbarContent -split "`r?`n"
        $inTopbar = $false
        $braceDepth = 0
        $newLines = @()
        $buttonCode = @"
		guiButtonType = {
			name = "${modName}_playsound"	
			spriteType = "GFX_button_music_player_play"
			orientation = "UPPER_RIGHT"
			position = { x = -340 y = 12 }
			clicksound = click
			shortcut = "v"
			scripted = yes
		}
"@

        for ($i=0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            if (-not $inTopbar -and $line -match '^\s*windowType\s*=\s*\{') {
                for ($j=$i; $j -lt $i+10; $j++) {
                    if ($j -lt $lines.Count -and $lines[$j] -match 'name\s*=\s*"topbar"') {
                        $inTopbar = $true
                        break
                    }
                }
            }
            
            if ($inTopbar) {
                $braceDepth += ([regex]::Matches($line, '\{')).Count
                $braceDepth -= ([regex]::Matches($line, '\}')).Count
                
                if ($braceDepth -eq 0) {
                    $newLines += $buttonCode
                    $newLines += $line
                    $inTopbar = $false
                    continue
                }
            }
            $newLines += $line
        }
        $newLines -join "`n" | Set-Content $buildTopbar
        Write-Host " -> Injected playsound button into topbar.gui successfully!" -ForegroundColor Green
    }
}

Write-Host "=========================================================" -ForegroundColor Red
Write-Host "REMINDER: DO NOT FORGET TO CREATE descriptor.mod MANUALLY!" -ForegroundColor Red
Write-Host "It should contain infos about dependencies and other details." -ForegroundColor Red
Write-Host "=========================================================" -ForegroundColor Red

Write-Host "Final Build Folder Assembled Successfully in /build/$modName !" -ForegroundColor Green