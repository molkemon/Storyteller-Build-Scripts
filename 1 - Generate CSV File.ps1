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

# Ensure folders exist
foreach ($folder in @($eventDescFolder, $soundFolder, $alteredEventsFolder, $customGuiFolder)) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-Output "Created folder: $folder"
    } else {
        Write-Output "Exists already: $folder"
    }
}

# Load localisation data into memory
$localisationTable = @{}
Write-Host "Creating localisation table..." -ForegroundColor Cyan
Get-ChildItem -Path $localisationFolder -Filter "*english.yml" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    foreach ($line in $content -split "`r?`n") {
        if ($line -match '^\s*([^:]+):(?:\d*)?\s*"(.*)"\s*$') {
            $key = $matches[1].Trim()
            $value = $matches[2]

            #loc icons
            $value = $value -replace '�.*?�', ''

            #colored strings
            $value = $value -replace '�.*?�!', ''
            
            # Normalize special characters
            $value = $value -replace '[������]', 'a'
            $value = $value -replace '[����]', 'e'
            $value = $value -replace '[����]', 'i'
            $value = $value -replace '[�����]', 'o'
            $value = $value -replace '[����]', 'u'
            $value = $value -replace '[��]', 'y'
            $value = $value -replace '[�]', 'c'
            $value = $value -replace '[�]', 'n'
            $value = $value -replace '[�]', 's'
            $value = $value -replace '[�]', 'z'
            $value = $value -replace '[�]', 'd'

            # Newlines and punctuation
            $value = $value -replace '�', '"'                  
            $value = $value -replace '�', '"'                  
			$value = $value -replace '(?:\s*\\n\s*)+', ' '
            $value = $value -replace '(\.\s*){2,}', '.'            
            $value = $value -replace '!', '.'
            $value = $value -replace '\s+\-+\s+', '; '
            $value = $value -replace '\-', ''
            $value = $value -replace '\s+\�+\s+', '; '
            $value = $value -replace '\�', ''
			$value = $value -replace ':', '.'
     
            #pronounciation aids
            $value = $value -replace '\sorc', ' ork'
            $value = $value -replace 'halforc', 'halfork'
            $value = $value -replace 'orcish', 'orkish'
            $value = $value -replace 'CLSTC', 'C L ASS T C'
            $value = $value -replace 'Aelantir', 'Aelantier'
			$value = $value -replace 'CLOAKERS', 'Cloakers'
            $value = $value -replace 'demesne', 'domain'
            $value = $value -replace 'Dames', 'Dames '            
            $value = $value -replace '\[DungeonOverlay\]', ''
            $value = $value -replace '\[EncounterOverlay\]', ''


            #whitespace before EOL
            $value = $value -replace '\s*$', ''

            $localisationTable[$key] = $value.Trim()
        }
    }
}
Write-Host "Localisation table created!" -ForegroundColor Green

# Create or Update the csv file
$csvData = @("`"eventFile`";`"eventId`";`"alreadyDone`";`"customLocRemaining`"")
$newEntries = @()

Write-Host "Parsing events..." -ForegroundColor Cyan

$eventFiles = Get-ChildItem -Path $eventsFolder -Filter "*.txt"
$totalFiles = $eventFiles.Count
$currentIdx = 0

foreach ($file in $eventFiles) {
    $currentIdx++
    Write-Progress -Activity "Parsing Events" -Status "File $currentIdx of $totalFiles $($file.Name)" -PercentComplete (($currentIdx / $totalFiles) * 100)

    $fileName = $file.Name
    $content = Get-Content $file.FullName -Raw

    # Solidified approach: strip comments and ALL option blocks completely from text 
    # to guarantee we don't pick up description keys belonging to options.
    $text = $content -replace '#.*', ''
    
    while ($true) {
        $optMatch = [regex]::Match($text, '(?i)\boption\s*=\s*\{')
        if (-not $optMatch.Success) { break }
        
        $startPos = $optMatch.Index
        $depth = 0
        $endPos = -1
        for ($i = $startPos; $i -lt $text.Length; $i++) {
            if ($text[$i] -eq '{') { $depth++ }
            elseif ($text[$i] -eq '}') {
                $depth--
                if ($depth -eq 0) {
                    $endPos = $i
                    break
                }
            }
        }
        if ($endPos -gt $startPos) {
            $text = $text.Remove($startPos, $endPos - $startPos + 1)
        } else {
            break # malformed block guard
        }
    }

    # Now find all desc = <key> in the remaining safe text
    $descMatches = [regex]::Matches($text, '(?im)^\s*desc\s*=\s*(?!\{)"?([^"\s{}]+)"?')
    
    foreach ($match in $descMatches) {
        $descKey = $match.Groups[1].Value.Trim()

        #Check if a soundfile for this event has already been generated
        $soundFilePath = Join-Path $soundFolder "$descKey.wav"
        $soundFileExists = if (Test-Path $soundFilePath) { "true" } else { "false" }
        
        #Check the existing description files generated by LLM model first
        $descFilePath = Join-Path $eventDescFolder "$descKey.txt"

        if (Test-Path $descFilePath) {   
            $desc = Get-Content -Path $descFilePath  
            $customLocRemaining = if ($desc -match '[��$\[\]]') { "true" } else { "false" }
            if ($desc.Trim().Length -eq 0) { continue }
        } elseif ($localisationTable.ContainsKey($descKey)) {
            $desc = $localisationTable[$descKey]
            $customLocRemaining = if ($desc -match '[$\[\]]') { "true" } else { "false" }
        } else {
            continue
        }

        $newEntries += "`"$fileName`";`"$descKey`";`"$soundFileExists`";`"$customLocRemaining`""
    }
}
Write-Progress -Activity "Parsing Events" -Completed

Write-Host "All events parsed and checked for existing LLM loc and soundfiles." -ForegroundColor Green

# Remove duplicates within the new set
$newEntries = $newEntries | Select-Object -Unique
Write-Host "Duplicates removed." -ForegroundColor Green

if (Test-Path $csvFile) {
    $existingLines = Get-Content $csvFile
    foreach ($entry in $newEntries) {
        if (-not ($existingLines -contains $entry)) {
            Add-Content -Path $csvFile -Value $entry
        }
    }
    Write-Host "Appended new entries to existing CSV file." -ForegroundColor Green
} else {
    $csvData += $newEntries
    $csvData = $csvData | Select-Object -Unique
    $csvData -join "`n" | Set-Content -Path $csvFile
    Write-Host "Generated event processing CSV file with all events." -ForegroundColor Green
}