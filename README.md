# The Commander's Automated Inference Pipeline (vLLM & F5-TTS)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Build scripts and resources to create the **Storyteller** mod for Europa Universalis IV (or any EU4 mod), which voices all in-game events using any TTS API Endpoint.

The scripts in this repository require available OpenAI-style API endpoints for text and audio inference. If you already have these, simply configure the paths in the scripts, ensure `ffmpeg` is installed, and you are ready to go. 

If you do not have available endpoints, or if you want a setup highly optimized for speed, follow the instructions below to create your own API endpoints locally.

> **⚠️ DISCLAIMER**
> This repository and the instructions below are provided **as-is**. Several steps, especially the WSL installation, make significant changes to your machine. Between WSL, two Python environments, the downloaded AI models, and the output sound files, you will need a massive amount of disk space (at least 100GB+). If you are entirely unfamiliar with command-line interfaces or Python environments, proceed with extreme caution.

## Time Requirements
* With a 3090 RTX, I managed to do all of Anbennar (over 20k events) in 14 hours. Vanilla only has 6k events and the events also have way less text, so it can be done in approx. 3-4 hours.

## Hardware Requirements
* **LLM Inference:** Minimum **12 GB VRAM** (You may need to use a smaller model than `gemma4:e4b` if you are at the minimum).
* **TTS Inference:** Minimum **6 GB VRAM**. 
* *Note: More VRAM speeds up the LLM, but doesn't significantly speed up TTS. However, raw GPU tensor power will speed up both.*

## Required Dependencies: FFmpeg
The audio processing scripts require `ffmpeg` to be installed and added to your Windows `PATH`. 

**The Easy Way (PowerShell):**
Open PowerShell as Administrator and run:
```powershell
winget install Gyan.FFmpeg
```
*Restart your terminal after installation. You can verify it works by typing `ffmpeg -version`.*

---

## Phase 0: The Script Setup (PowerShell 7)

**0. The general Workflow:**

- You have 6 PowerShell scripts in this pipeline. To create the mod, you have to first setup the configuration blocks for all scripts, and then execute the scripts one after the other.
- Only execute in PowerShell 7, one of the scripts absolutely requires it, and all of the scripts are way faster in 7.
  
- For Script 2 you need an available LLM endpoint, for Script 3 you need a TTS endpoint. Setup on how to run those locally for free and highly optimized for speed are further below.
  
- Script 1 creates a csv file indexing all event descriptions found in all event files for the selected mod.
- Script 2 turns the localisation for events for the selected mod into normal text that has been cleaned of dynamic localisation tags like [Root.Monarch.GetTitle] etc.
  - This repo currently already contains these cleaned up event files for both Vanilla and Anbennar (Gitlab version pulled on April 22nd 2026, should be this commit version: https://gitlab.com/anbennar/anbennar-eu4-dev/-/tree/57fdaff9b187fd39c9b9c7ef062b9228a82bf0cf).
  - So if you want to revoice either Vanilla or Anbennar, you can skip this script entirely and if you want to setup your own local endpoints, you can skip the vLLM part, allthough Anbennar still gets constant updates and the new events will either not be voiced or missing alltogether if you do this. 
- Script 3 turns the clean eventdescriptions from Script 2 into waveform audio files the game can play and adds those files to an asset index file.
- Script 4 creates new versions of the selected mods event files that injects additional effects into every single event in game to make the play button appear when the event triggers in game.
- Script 5 creates a custom_gui file for the play button with the required logic to play the corret sound effect for whichever event triggered it showing up.
- Script 6 creates localisation for the play button (so it has a tooltip) and updates the selected mods topbar.gui file to support the play button. If the selected mod does not have a topbar.gui file, the vanilla one is used.

- Scripts 2-4 should be save to "pause" (via killing them with ctr-c) as all of them should resume where they left off on further execution. The other scripts don't take long enough for this to be a concern. 

  

**1. Always use PowerShell 7:**
If you haven't upgraded, run:
```powershell
winget install --id Microsoft.Powershell --source winget
```
Restart Windows Terminal, click the down-arrow > **Settings** > **Startup** > **Default Profile** > select **PowerShell** (the black logo).

**2. The "Configure Once" Rule:**
Every script is divided into two sections: `CONFIGURATION` and `SCRIPT CODE`.
1. Edit the directory paths in the `CONFIGURATION` section of the *first* script.
2. Copy that `CONFIGURATION` block.
3. Paste it over the `CONFIGURATION` block of the other 5 scripts.
4. **DO NOT** change anything below the `# --- Script Code ---` marker.

> NOTE: If you already have LLM and TTS endpoints available to you, you are good to go now and can ignore anything below.
> The below instructions will create endpoints which are highly optimized for speed, but there is like a million other ways you can go about this. You could use cloud providers, runpods, or use premade suites that run on Windows and have easier installs, like e.g. ollama for the LLM part.
> As already mentioned above, executing the below steps requires signifcant amounts of disk space and should probably not be attempted if you have absolutely no idea what you are doing. 

---

## Phase 1: The Prerequisite (WSL)

Before running the local AI engines, you need the Windows Subsystem for Linux (WSL). For more detailed installation instructions see here: https://learn.microsoft.com/en-us/windows/wsl/install

1. Open PowerShell (Admin) and run:
   ```powershell
   wsl --install
   ```
2. Restart your machine. 
3. Open a fresh Ubuntu (WSL) tab in your Terminal and install Miniconda:
   ```bash
   wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
   bash Miniconda3-latest-Linux-x86_64.sh
   ```
4. Follow the prompts. Close the Ubuntu tab and open a new one. Your command line should now start with `(base)`.

---

### Phase 1.5: The Hugging Face Tollbooth

Many of the top-tier AI models are "gated." You can't just scrape them off the server anonymously; you have to politely identify yourself first. 

1. **Create an Account:** Go to [huggingface.co](huggingface.co) and register for a free account. 
2. **Acknowledge the TOS:** Search for the specific models you plan to use (e.g., `google/gemma-4-E4B-it`) on Hugging Face. If there is a big banner asking you to agree to share your contact info to access the model, and you are fine with that, click it and accept the terms. 
3. **Get Your Token:** Go to your Hugging Face **Settings > Access Tokens** and create a new token (Read-only permissions are fine). 
4. **Bake it into WSL:** You want this token permanently available for later use so you never have to think about it again. Open your Ubuntu terminal and run this exact command, replacing the placeholder with your actual token:

```bash
echo 'export HF_TOKEN="your_actual_token_goes_here"' >> ~/.bashrc
source ~/.bashrc
```

*Now your WSL system will automatically flash this VIP pass whenever any Python script tries to download a model.*

---

## Phase 2: Building the Conda Environments

> **NOTE:** While you can copy-paste these code blocks directly into your Ubuntu terminal, it is highly recommended to keep them saved as files on hand for future troubleshooting and re-runs.

> **CRITICAL WARNING:** If you create `.sh` files in Windows using Notepad++, you **MUST** ensure the line endings are correct: `Edit -> EOL Conversion -> Unix (LF) -> Save`.

### Environment A: vLLM
Create a file named `create_vllm_env.sh` inside WSL and run it:

```bash
#!/bin/bash
conda create -n vllm_engine python=3.10 -y
eval "$(conda shell.bash hook)"
conda activate vllm_engine
pip install vllm
```

### Environment B: F5-TTS
Create a file named `create_f5_env.sh` inside WSL and run it:

```bash
#!/bin/bash
set -e
eval "$(conda shell.bash hook)"
conda create -n f5 python=3.10 -y
conda activate f5
pip install torch==2.4.0 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
git clone https://github.com/SWivid/F5-TTS.git
cd F5-TTS
pip install -e .
pip install ninja
pip install packaging
pip install wheel
pip install triton
pip install flash-attn --no-build-isolation
pip install deepspeed
```

---

## Phase 3: The Fast TTS Server

Navigate into your cloned F5-TTS folder:
```bash
cd ~/F5-TTS
```

### Setting Up Your Reference Voice
Before you fire up the server, you need to give the TTS engine the voice you want for narration.
1. Create a subfolder named `voices` inside the `F5-TTS` directory:
   ```bash
   mkdir voices
   ```
2. Drop a reference audio file into this new `voices` folder (e.g. `narrator_ahegao_girl.wav`). 
3. In the next script, make sure to set REF_TEXT to the exact text that is spoken in this wav.
4. Best practice if you want to experiment with multiple voices: also create a txt file alongside each wav (e.g. `narrator_ahegao_girl.txt`) and save the reference text there aswell.
5. If you are happy with the voice, but it's reading too slow or too fast you can adjust the narration speed by changing speed=0.9 to something higher or lower in the file we are about to create. 

**The Golden Rules for Reference Audio:**
* **Format:** It **must** be a `.wav` file. 
* **Length:** Keep it between 6 to 8 seconds. Too short and it struggles to catch the cadence; too long and it might start hallucinating.
* **Quality:** Crystal clear speech only. Absolutely no background music, sound effects, or heavy room echo, unless you want your events narrated by someone who sounds like they're trapped in a tin can at a rave.



Create a file named `fast_f5_server.py` and paste the following code:

```python
import time
import torch
import torchaudio
import tempfile
import os
from fastapi import FastAPI, Form, BackgroundTasks
from fastapi.responses import FileResponse
from f5_tts.api import F5TTS

app = FastAPI()

# --- CONFIGURATION ---
REF_AUDIO = "voices/narrator.wav"  # MUST BE A WAV FILE
REF_TEXT = "This is the example text spoken by your chosen narrator in the wav file."  # Make sure this does not have typos.
# ---------------------

print("Spinning up the F5-TTS engine...")
f5tts = F5TTS(model="F5TTS_v1_Base", device="cuda")
print("Engine hot. Waiting for targets on port 7851.")

def remove_temp_file(path: str):
    if os.path.exists(path):
        os.remove(path)
        print(f"[-] Scrubbed temp file: {path}")

@app.post("/api/tts-generate")
async def generate_tts(background_tasks: BackgroundTasks, text_input: str = Form(...)):
    print(f"\n[+] Incoming request. Text length: {len(text_input)} characters.")
    start_time = time.time()
    
    # Generate audio
    wav, sr, spect = f5tts.infer(
        ref_file=REF_AUDIO,
        ref_text=REF_TEXT,
        gen_text=text_input,
        nfe_step=7,
        cfg_strength=2.0,
        speed=0.9   # Use this to control narration speed. 
    )
    
    gen_time = time.time() - start_time
    audio_duration = len(wav) / sr
    rtf = gen_time / audio_duration
    print(f"[+] Generation complete. RTF: {rtf:.3f} | Audio length: {audio_duration:.2f}s")

    # Save to a temporary file
    temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
    torchaudio.save(temp_file.name, torch.tensor(wav).unsqueeze(0), sr)
    
    # Cleanup after response
    background_tasks.add_task(remove_temp_file, temp_file.name)
    
    return FileResponse(temp_file.name, media_type="audio/wav", filename="output.wav")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7851)
```

---

## Phase 4: The Ignition Scripts

> **VRAM LIMITATION:** Unless you are running server-grade hardware, you cannot run both engines simultaneously. Kill one using `Ctrl+C` before starting the other.

Create these two trigger scripts in your WSL home folder (`~/`). Ensure they are saved with LF line endings.

### `vllm.sh`
```bash
#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh 2>/dev/null || source ~/anaconda3/etc/profile.d/conda.sh 2>/dev/null
conda activate vllm_engine
python -m vllm.entrypoints.openai.api_server \
    --model google/gemma-4-E4B-it \
    --gpu-memory-utilization 0.9 \
    --port 8000
```

### `f5.sh`
```bash
#!/bin/bash
source ~/miniconda3/etc/profile.d/conda.sh 2>/dev/null || source ~/anaconda3/etc/profile.d/conda.sh 2>/dev/null
conda activate f5
cd ~/F5-TTS
python fast_f5_server.py
```

### Execution Protocol
Arm the scripts once by running:
```bash
chmod +x vllm.sh f5.sh
```

**Workflow:**

1. **Text Processing:** Run `./vllm.sh`. Keep this terminal open while you execute `2 - Remove Dynamic Loc with LLM.ps1` in PowerShell. 
2. **Audio Generation:** Kill the vLLM server (`Ctrl+C`). Run `./f5.sh`. Keep this terminal open while you execute `3 - Text to Speech.ps1` in PowerShell.
