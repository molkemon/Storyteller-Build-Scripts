#=======================================================
# Mod Selection
#=======================================================

#This is the name of the mod you want to make to better distinguish versions for different mods, e.g storyteller_vanilla, $storyteller_anbennar_steam, storyteller_meiou etc
$modName = "storyteller_anbennar_steam"

#Set this to the name of another mod to scavenge existing event descriptions and sound files from it. Leave empty ("") to disable.
$copyFromModName = ""

# Base Game Folder (Required for vanilla localization fallback)
$vanillaGameFolder = "D:\Steam\steamapps\common\Europa Universalis IV"

#This needs to point at the root directory of either the base game if you want to do vanilla, or the root folder of the mod if you want to do any mod
#$rootFolder = "D:\Steam\steamapps\common\Europa Universalis IV"                                         #EU 4 Vanilla
$rootFolder = "D:\Steam\steamapps\workshop\content\236850\1385440355"                                   #Anbennar Steam version
#$rootFolder = "C:\Users\grand\Documents\Paradox Interactive\Europa Universalis IV\mod\Anbennar-PublicFork"       #Anbennar GitLab Version

#Your EU4 mod folder
$modFolder = "C:\Users\grand\Documents\Paradox Interactive\Europa Universalis IV\mod"


#=======================================================
# Script Folder Configuration
#=======================================================

$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$localisationFolder = [System.IO.Path]::Combine($rootFolder, "localisation")
$vanillaLocalisationFolder = [System.IO.Path]::Combine($vanillaGameFolder, "localisation")
$eventsFolder = [System.IO.Path]::Combine($rootFolder, "events")
$eventDescFolder = [System.IO.Path]::Combine($scriptFolder, "eventdescriptions", $modName)
$modOutputFolder = [System.IO.Path]::Combine($scriptFolder, "build", $modName)
$soundFolder = [System.IO.Path]::Combine($modOutputFolder, "sound")
$alteredEventsFolder = [System.IO.Path]::Combine($modOutputFolder, "events")
$customGuiFolder = [System.IO.Path]::Combine($modOutputFolder, "common", "custom_gui")

$csvFile = [System.IO.Path]::Combine($scriptFolder, "filelist_$modName.csv")
$assetFile = [System.IO.Path]::Combine($soundFolder, "$modName.asset")
$customGuiFile = [System.IO.Path]::Combine($customGuiFolder, "$modName.txt")

# Scavenging paths
if ($copyFromModName -ne "") {
    $copyFromEventDescFolder = [System.IO.Path]::Combine($scriptFolder, "eventdescriptions", $copyFromModName)
    $copyFromSoundFolder = [System.IO.Path]::Combine($scriptFolder, "build", $copyFromModName, "sound")
}


#=======================================================
# Text Correction Configuration
#=======================================================

# Pre-LLM Scan: If these words are found in the generated file but NOT in the original loc, the file is deleted and re-queued.
$wordsToTriggerRegen = @(
    "TODO",
    "placeholder"
)

# Post-LLM Scan: Hashtable of words to replace after the LLM finishes. 
# Format: @{ "BadWord" = "GoodWord" }
# The script will first search for the BadWord in the original loc to see if this was actually the intended word. If not, it will replace BadWord with GoodWord
$postLlmReplace = @{
    "mechanism" = "mechanim"
    "mechanisms" = "mechanim"
}


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
1. REPLACE ALL TAGS: Replace all dynamic variables (e.g., [Root.Monarch.GetName], `$COUNTRY`$, EVERYTHING between brackets or dollar signs) with generic, natural-sounding spoken words based on context. If you are unable to determine the context by reading the entire sentence, you can also remove the dynamic loc tag entirely, but only if the sentence still makes sense after the removal. If additional (non dynamic loc) words must be changed for the replacement word to make sense, you may do so, but only do this to ensure the sentence makes sense, do not change other words randomly. Overall, just ensure that no dynamic loc remains while trying to keep as faithfully to the original text as possible. FROM THE CONTEXT OF THE ENTIRE SENTENCE, DECIDE ON WETHER THE EVENT IS A COUNTRY OR A PROVINCE EVENT AND MAKE LOC REPLACEMENTS ACCORDINGLY.
2. CONTEXTUAL RULES:
   - Often the dynamic loc hints at what it is supposed to be via it's name, ie `$ADM_Advisor`$ would be our administrative advisor or [empire_of_china.GetAdjective] would be the adjective of whichever country currently holds the Mandate of Heaven, so a possible substitution that somewhat makes sense no matter the country could be "celestial". 
   - Locations: use "country", "province", "realm", or "domain".
   - Rulers/People: use "lord", "ruler", "monarch", "heir", or "advisor".
   - Pronouns: substitute with "they/their" where appropriate.
   - Dates ([GetDate], [GetYear]): use "today", "now", "currently", or remove entirely if redundant.
   - The Mechanim are a race, not a typo, do not replace Mechanim with mechanism
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

$csvData = Import-Csv -Path $csvFile -Delimiter ";"
$initialTotal = @($csvData).Count

$verifiedDoneCount = 0
$recoveredCount = 0
$todoList = @()

Write-Host "Cross-referencing CSV with existing audio files..." -ForegroundColor Cyan

foreach ($row in $csvData) {
    $outputFilePath = Join-Path $soundFolder "$($row.eventId).wav"
    $fileExists = (Test-Path $outputFilePath) -and ((Get-Item $outputFilePath).Length -gt 0)

    if ($fileExists) {
        if ($row.alreadyDone -eq "true") {
            $verifiedDoneCount++
        } else {
            $row.alreadyDone = "true"
            $recoveredCount++
        }
    } else {
        $row.alreadyDone = "false"
        
        # We can only process it if the text description actually exists
        $descFilePath = Join-Path $eventDescFolder "$($row.eventId).txt"
        if ((Test-Path $descFilePath) -and ((Get-Item $descFilePath).Length -gt 0)) {
            $todoList += $row
        }
    }
}

$sessionTarget = @($todoList).Count

Write-Host ""
Write-Host "=================================================" -ForegroundColor Magenta
Write-Host " PRE-FLIGHT REPORT" -ForegroundColor White
Write-Host " Total Events in CSV:        $initialTotal"
Write-Host " Verified Complete (Audio):  $verifiedDoneCount" -ForegroundColor Green
Write-Host " Recovered (Fixed Desync):   $recoveredCount" -ForegroundColor Yellow
Write-Host " Queued for TTS Engine:      $sessionTarget" -ForegroundColor Red
Write-Host "=================================================" -ForegroundColor Magenta
Write-Host ""

if ($sessionTarget -eq 0) {
    Write-Host "All audio files exist. The queue is completely empty." -ForegroundColor Green
    $csvData | Export-Csv -Path $csvFile -NoTypeInformation -Delimiter ";"
    
    # Still want to jump to the asset rebuild in case something changed
    Goto Rebuild-Assets 
}


#=======================================================
# The Execution Phase
#=======================================================

Write-Host "Starting Text to Speech generation..." -ForegroundColor Cyan
$currentProgress = 0

foreach ($eventEntry in $todoList) {
    $currentProgress++
    $descKey = $eventEntry.eventId
    
    $percentage = [math]::Min(100, [math]::Max(0, [math]::Round(($currentProgress / $sessionTarget) * 100)))
    Write-Progress -Activity "Generating TTS audio" -Status "Event $currentProgress of $sessionTarget | $descKey" -PercentComplete $percentage

    $descFilePath = Join-Path $eventDescFolder "$descKey.txt"
    $desc = Get-Content -Path $descFilePath -Raw
    
    # Just in case whitespace slipped past the pre-flight
    if ([string]::IsNullOrWhiteSpace($desc)) {
        continue
    }

    $outputFileName = $descKey
    $outputFilePath = Join-Path $soundFolder "$outputFileName.wav"
    $tempFilePath = Join-Path $soundFolder "temp_$outputFileName.wav"
    
    # One clean API call. The server returns the wav directly to our temp file.
    $body = @{ text_input = $desc }
    try {
        Invoke-RestMethod -Uri $ttsApiUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded" -OutFile $tempFilePath
    } catch {
        Write-Warning "API call failed for $descKey. Is the Python server running?"
        continue
    }
    
    # F5-TTS outputs 24kHz. EU4 demands 16kHz pcm_u8. Re-encode the single file.
    ffmpeg -i "$tempFilePath" -ar 16000 -ac 1 -c:a pcm_u8 -filter:a "volume=2.00" "$outputFilePath" -loglevel quiet -y
    Remove-Item -Path $tempFilePath -ErrorAction SilentlyContinue

    Write-Host " -> Saved wave file to $outputFilePath" -ForegroundColor Green
}

# Clear the progress bar when finished
Write-Progress -Activity "Generating TTS audio" -Completed


#=======================================================
# Post-Flight Debrief & Save
#=======================================================

Write-Host "Re-evaluating hard drive to confirm kills..." -ForegroundColor Cyan

$finalDoneCount = 0
foreach ($row in $csvData) {
    $outputFilePath = Join-Path $soundFolder "$($row.eventId).wav"
    if ((Test-Path $outputFilePath) -and ((Get-Item $outputFilePath).Length -gt 0)) {
        $row.alreadyDone = "true"
        $finalDoneCount++
    }
}

$processedThisSession = $finalDoneCount - ($verifiedDoneCount + $recoveredCount)

Write-Host ""
Write-Host "=================================================" -ForegroundColor Magenta
Write-Host " POST-FLIGHT DEBRIEF" -ForegroundColor White
Write-Host " Newly Generated Audio:      $processedThisSession" -ForegroundColor Green
Write-Host " Total Audio Completion:     $finalDoneCount / $initialTotal" -ForegroundColor Yellow
Write-Host "=================================================" -ForegroundColor Magenta

$csvData | Export-Csv -Path $csvFile -NoTypeInformation -Delimiter ";"
Write-Host "CSV successfully updated." -ForegroundColor Cyan


#=======================================================
# Rebuild Asset File
#=======================================================

Write-Host "Rebuilding asset file from existing audio files..." -ForegroundColor Cyan

$assetContent = @()
$wavFiles = Get-ChildItem -Path $soundFolder -Filter "*.wav"
$validFileCount = 0

foreach ($wavFile in $wavFiles) {
    # Skip any lingering temp files just in case ffmpeg crashed and didn't clean up
    if ($wavFile.Name -match "^temp_") {
        continue
    }

    $soundName = $wavFile.BaseName
    
    $assetContent += "sound = {"
    $assetContent += "`tname = $soundName"
    $assetContent += "`tfile = `"$($wavFile.Name)`""
    $assetContent += "`talways_load = no"
    $assetContent += "}"
    $assetContent += ""
    
    $validFileCount++
}

$assetContent | Set-Content -Path $assetFile -Force
Write-Host "Asset index rebuilt successfully with $validFileCount entries. Standing by." -ForegroundColor Green