#=======================================================
# Mod Selection
#=======================================================

#This is the name of the mod you want to make to better distinguish versions for different mods, e.g storyteller_vanilla, $storyteller_anbennar_steam, storyteller_meiou etc
#$modName = "storyteller_vanilla"
#$modName = "storyteller_anbennar_steam"
#$modName = "storyteller_anbennar_gitlab"     #I use anbennar as an example to show the difference between vanilla and any mod

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

$previouslyDone = "false"
$csvData = Import-Csv -Path $csvFile -Delimiter ";"
$totalCount = @($csvData).Count
$currentCount = 0

Write-Host "Starting Text to Speech generation..." -ForegroundColor Cyan

foreach ($eventEntry in $csvData) {
    $currentCount++
    if ($eventEntry.alreadyDone -eq "true") {
        continue
    }
    
    $descKey = $eventEntry.eventId
    Write-Progress -Activity "Generating TTS audio" -Status "Event $currentCount of $totalCount $descKey" -PercentComplete (($currentCount / $totalCount) * 100)

    $descFilePath = Join-Path $eventDescFolder "$descKey.txt"
    
    if (-not (Test-Path $descFilePath)) {
        Write-Warning "Description file for $descKey not found. Skipping."
        continue
    }

    $desc = Get-Content -Path $descFilePath -Raw
    
    # Catch empty files before we bother the API
    if ([string]::IsNullOrWhiteSpace($desc)) {
        continue
    }

    $outputFileName = $descKey
    $outputFilePath = Join-Path $soundFolder "$outputFileName.wav"
    $tempFilePath = Join-Path $soundFolder "temp_$outputFileName.wav"
    
    if (Test-Path $outputFilePath) {
        $previouslyDone = "true"
    } else {
        $previouslyDone = "false"
    }
    
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
    
    # Add to asset file only if hasn't been done and not already present
    if ($previouslyDone -eq "false") {
        $assetContent = if (Test-Path $assetFile) { Get-Content $assetFile -Raw } else { "" }
        
        # Check to ensure no double entries
        if ($assetContent -notmatch "name\s*=\s*`"$outputFileName`"" -and $assetContent -notmatch "name\s*=\s*$outputFileName\b") {
            $assetEntry = @(
                 "sound = {",
                 "	name = $outputFileName",
                 "	file = ""$outputFileName.wav""",
                 "	always_load = no",
                 "}",
                 ""
            )
            Add-Content -Path $assetFile -Value $assetEntry
            Write-Host " -> Appended $outputFileName to asset index." -ForegroundColor Yellow
        }
    }

    $previouslyDone = "false"
    $eventEntry.alreadyDone = "true"
    $csvData | Export-Csv -Path $csvFile -NoTypeInformation -Delimiter ";"
}

Write-Host "TTS Processing complete!" -ForegroundColor Cyan