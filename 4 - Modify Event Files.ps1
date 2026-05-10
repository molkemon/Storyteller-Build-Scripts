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
$eventCounter = 1 
$eventCounterPlusOne = 2

Write-Host "Modifying Event Files (Synchronized Mode)..." -ForegroundColor Cyan

if (!(Test-Path $alteredEventsFolder)) { New-Item -ItemType Directory -Path $alteredEventsFolder -Force | Out-Null }

# Load and SORT the CSV to ensure ID synchronization with Script 5
$csvData = Import-Csv -Path $csvFile -Delimiter ";" | Where-Object { ![string]::IsNullOrWhiteSpace($_.eventFile) -and ![string]::IsNullOrWhiteSpace($_.eventId) } | Sort-Object eventFile, eventId

$eventsByFile = $csvData | Group-Object eventFile
$totalFiles = $eventsByFile.Count
$currentFileIdx = 0

foreach ($fileGroup in $eventsByFile) {
    $currentFileIdx++
    $eventFile = $fileGroup.Name
    $sourceFile = Join-Path $eventsFolder $eventFile
    $destinationFile = Join-Path $alteredEventsFolder $eventFile

    Write-Progress -Activity "Injecting Event Logic" -Status "File $currentFileIdx of $totalFiles $eventFile" -PercentComplete (($currentFileIdx / $totalFiles) * 100)

    if (!(Test-Path $sourceFile)) {
        Write-Warning "Missing source file: $sourceFile. Skipping but incrementing counters to maintain sync."
        foreach ($entry in $fileGroup.Group) { $eventCounter++; $eventCounterPlusOne++ }
        continue
    }

    # Always pull a clean copy to avoid accumulation
    $modFileContent = Get-Content $sourceFile | ForEach-Object { ($_ -replace '#.*$', '').TrimEnd() }

    foreach ($eventEntry in $fileGroup.Group) {
        $descKey = $eventEntry.eventId

        # Reserve the ID but skip injection for the settings menu
        if ($descKey -eq "anb_settings.1.d") {
            $eventCounter++; $eventCounterPlusOne++
            continue
        }

        $lineCount = @($modFileContent).Count
        $updatedContent = New-Object System.Collections.Generic.List[string]
        
        $descFound = $false
        $descFoundWithTrigger = $false
        $currentTrigger = $false
        $scope = "country"
        $insideEventHeader = $false

        for ($i = 0; $i -lt $lineCount; $i++) {
            $line = $modFileContent[$i]

            # Detect start of an event block and reset flags
            if ($line -match "^(country_event|province_event)\s*=\s*\{") { 
                $scope = if ($line -match "^country_event") { "country" } else { "province" }
                $insideEventHeader = $true
                $descFound = $false
                $descFoundWithTrigger = $false
            }

            # Only look for descriptions if we are inside the header phase of an event
            if ($insideEventHeader) {
                # Look ahead for existing logic to prevent double injection in triggered desc blocks
                if ($line -match "^\s*desc\s*=\s*\{") {
                    $startIndex = $i
                    $braceDepth = 1
                    $blockLines = New-Object 'System.Collections.Generic.List[string]'
                    $blockLines.Add($line)

                    for ($j = $i + 1; $j -lt $lineCount; $j++) {
                        $blockLine = $modFileContent[$j]
                        $blockLines.Add($blockLine)
                        $braceDepth += ([regex]::Matches($blockLine, '\{')).Count
                        $braceDepth -= ([regex]::Matches($blockLine, '\}')).Count
                        if ($braceDepth -le 0) { break }
                    }

                    # SAFEGUARD: Check if block already has logic
                    if ($blockLines -join " " -match "set_variable\s*=\s*\{\s*which\s*=\s*${modName}_id") {
                        Write-Host " [!] Logic already exists for $descKey in triggered desc. Skipping." -ForegroundColor Yellow
                    } else {
                        $containsTrigger = $false
                        $containsDescKey = $false
                        $currentTriggerLines = New-Object 'System.Collections.Generic.List[string]'
                        $inTriggerBlock = $false
                        $triggerBraceDepth = 0

                        foreach ($descLine in $blockLines) {
                            if ($descLine -match "^\s*trigger\s*=\s*\{") {
                                $containsTrigger = $true
                                $inTriggerBlock = $true
                                $triggerBraceDepth += ([regex]::Matches($descLine, '\{')).Count
                                $triggerBraceDepth -= ([regex]::Matches($descLine, '\}')).Count
                                $cleaned = $descLine -replace "^.*?\{", ""
                                if ($triggerBraceDepth -le 0) {
                                    $inTriggerBlock = $false
                                    $cleaned = $cleaned -replace "\}\s*$", ""
                                    if ($cleaned.Trim()) { $currentTriggerLines.Add($cleaned) }
                                    continue
                                } else {
                                    if ($cleaned.Trim()) { $currentTriggerLines.Add($cleaned) }
                                    continue
                                }
                            }
                            if ($inTriggerBlock) {
                                $triggerBraceDepth += ([regex]::Matches($descLine, '\{')).Count
                                $triggerBraceDepth -= ([regex]::Matches($descLine, '\}')).Count
                                if ($triggerBraceDepth -le 0) {
                                    $inTriggerBlock = $false
                                    $cleaned = $descLine -replace "\}\s*$", ""
                                    if ($cleaned.Trim()) { $currentTriggerLines.Add($cleaned) }
                                    continue
                                } else {
                                    $currentTriggerLines.Add($descLine)
                                    continue
                                }
                            }
                            if ($descLine -match "^\s*desc\s*=\s*`"?$descKey`"?") { $containsDescKey = $true }
                        }

                        if ($containsTrigger -and $containsDescKey) {
                            $descFoundWithTrigger = $true
                            $currentTrigger = ($currentTriggerLines -join ' ') -replace '\s+', ' '
                        }
                    }
                } elseif (!$currentTrigger -and $line -match "^\s*desc\s*=\s*`"?$descKey`"?") {
                    # Check for double injection in flat desc lines
                    $flatCheck = $modFileContent[$i..($i+20)] -join " "
                    if ($flatCheck -match "set_variable\s*=\s*\{\s*which\s*=\s*${modName}_id") {
                         # Already injected here in a previous pass
                    } else {
                         $descFound = $true
                    }
                }
            }

            # If we hit an option block...
            if ($line -match "^\s*option\s*=\s*\{") { 
                # If we are in the header phase and found our description, drop the payload
                if ($insideEventHeader -and ($descFound -or $descFoundWithTrigger)) {
                    $target = if ($scope -eq "country") { "" } else { "owner = { " }
                    $closer = if ($scope -eq "country") { "" } else { " }" }
                    
                    $insertBlock = @(
                        "    immediate = {",
                        "        if = { limit = { $(if($descFoundWithTrigger){$currentTrigger}) $(if($scope -eq "province"){"owner = {"}) ai = no check_variable = { which = storyteller_autoplay value = 1 } $(if($scope -eq "province"){"}"}) } hidden_effect = { play_sound = $descKey } }",
                        "        else_if = { limit = { $(if($descFoundWithTrigger){$currentTrigger}) $(if($scope -eq "province"){"owner = {"}) ai = no $(if($scope -eq "province"){"}"}) } hidden_effect = { $target set_variable = { which = ${modName}_id value = $eventCounter } $closer } }",
                        "    }",
                        "    after = { if = { limit = { $target ai = no check_variable = { which = ${modName}_id value = $eventCounter } NOT = { check_variable = { which = ${modName}_id value = $eventCounterPlusOne } } $closer }  hidden_effect = { $target set_variable = { which = ${modName}_id value = 0 } $closer } } }",
                        ""
                    )
                    
                    foreach ($insertLine in $insertBlock) {
                        $updatedContent.Add($insertLine)
                    }
                    
                    # Reset flags for this specific event's injection
                    $descFound = $false
                    $descFoundWithTrigger = $false
                }
                
                # Turn off the header phase so we don't scan for descriptions inside options
                $insideEventHeader = $false
                $updatedContent.Add($line)
                continue
            }
            
            # Normal line add if it wasn't an option block injection
            $updatedContent.Add($line)
        }
        $modFileContent = $updatedContent.ToArray()
        $eventCounter++; $eventCounterPlusOne++
    }
    $modFileContent | Set-Content $destinationFile
}
Write-Host "Event modifications complete! All IDs synchronized." -ForegroundColor Cyan