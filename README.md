# HPC Cluster – How To Connect & Run Experiments (Ollama)

This guide explains how to connect to the unibz ScientificNet HPC cluster, start an Ollama server on a compute node (GPU), and run experiments from your local machine via SSH port forwarding.

---

## 0. Prerequisites

- An active HPC account (`mdipanfilo@login.hpc.scientificnet.org`)
- SSH access configured on your local machine
- Basic familiarity with `ssh`, `sbatch`, and `squeue`
- Local machine with `curl`

**Official documentation**
- https://hpc.scientificnet.org/help/
- GPU guide: https://hpc.scientificnet.org/help/guide/gpu/

---

## 1. Get the Files (Two Options)

You can either clone the repository from GitHub (recommended) or create the files manually.

---

### Option A – Clone from GitHub (Recommended)

Clone the repository on the HPC login node:

```bash
git clone https://github.com/marcodipanfilo/ollama-hpc.git
```

This creates the folder:

```text
~/ollama-hpc
```

Move into the unibz-specific subfolder:

```bash
cd ~/ollama-hpc/unibz
```

---

### Option B – Create the Files Manually

If you do **not** use GitHub, create the same directory structure manually:

```bash
mkdir -p ~/ollama-hpc/unibz
cd ~/ollama-hpc/unibz
```

Then create the files manually:

- `run.batch`
- `run_example.batch`

⚠️ **Important**

- Whether you clone from GitHub or create files manually, the working directory is:

```text
~/ollama-hpc/unibz
```

This ensures paths and commands are identical in both cases.

---

## 2. First-Time Setup (HPC)

### 2.1 Check if Ollama is installed

```bash
which ollama
```

If Ollama is not installed:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

This installs Ollama into:

```text
$HOME/.local/bin/ollama
```

Make sure the path is available:

```bash
export PATH=$HOME/.local/bin:$PATH
```

---


## 3. SSH Convenience (Recommended)

To avoid typing passwords every time, copy your local public key to the HPC login node.

### 3.1 On the HPC login node

If the `.ssh` directory does not exist yet, create it first:

```bash
mkdir -p ~/.ssh
```

Then proceed with:

```bash
cd ~/.ssh
vi authorized_keys
```

Paste your local public key (`id_ed25519.pub`) into this file.

Set correct permissions:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

---

## 4. Batch Scripts

You will use Slurm to start Ollama on a GPU node.

### 4.1 Example test batch (`run_example.batch`)

```bash
#!/bin/bash
#SBATCH --job-name=ollama-test
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --gres=gpu:1
#SBATCH --constraint=gpu32g
#SBATCH --account=vkg_mpboot
#SBATCH --partition=gpu-pre
#SBATCH --output=%j.out
#SBATCH --error=%j.err

module load cuda
export PATH=$HOME/.local/bin:$PATH

export GIN_MODE=release
export OLLAMA_HOST=0.0.0.0
export OLLAMA_MODELS=/data/users/mdipanfilo/ollama

ollama serve >/dev/null 2>&1 &
sleep 5

ollama pull deepseek-r1:8b
ollama run deepseek-r1:8b "What is the capital of Italy?"
ollama list
```

Useful for validating GPU access and model download.

---

### 4.2 Production batch (`run.batch`)

```bash
#!/bin/bash
#SBATCH --job-name=ollama-test
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=100G
#SBATCH --time=02:00:00
#SBATCH --gres=gpu:1
#SBATCH --constraint=gpu32g
#SBATCH --account=vkg_mpboot
#SBATCH --partition=gpu-pre
#SBATCH --output=%j.out
#SBATCH --error=%j.err

module load cuda
export PATH=$HOME/.local/bin:$PATH

hostname > $PWD/nodename.txt

export GIN_MODE=release
export OLLAMA_HOST=0.0.0.0
export OLLAMA_MODELS=/data/users/mdipanfilo/ollama

ollama serve
```

This starts a persistent Ollama server on the allocated node.

---

## 5. Running Jobs

### 5.1 Connect to HPC

```bash
ssh mdipanfilo@login.hpc.scientificnet.org
```

### 5.2 Go to working directory

```bash
cd ~/ollama-hpc/unibz
```

### 5.3 Submit job

```bash
sbatch run.batch
```

Slurm returns a **JOBID**, for example:

```text
Submitted batch job 156895
```

---

### 5.4 Check job status

```bash
squeue -u mdipanfilo
```

Example output:

```text
JOBID   STATE    NODELIST
156895 RUNNING  hpcsgn02
```

---

### 5.5 Inspect logs

```bash
tail -f 156895.out
```

(Change the file name to the job ID you see in `squeue`.)

---

## 6. Port Forwarding (Local → HPC GPU Node)

Once the job is **RUNNING**, Ollama listens on port `11434` on the compute node, not on the login node.

The batch script writes the node name to:

```text
~/ollama-hpc/unibz/nodename.txt
```

### 6.1 Open a new local terminal

```bash
ssh -N -L 5000:$(ssh mdipanfilo@login.hpc.scientificnet.org "cat ~/ollama-hpc/unibz/nodename.txt"):11434 mdipanfilo@login.hpc.scientificnet.org
```

This forwards:

```text
localhost:5000 → GPU node:11434
```

Leave this terminal open.

---

## 7. Sending Requests

From your local machine:

```bash
curl -s -X POST http://localhost:5000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model":"deepseek-r1:8b",
    "stream":false,
    "messages":[
      {"role":"user","content":"What are VKG mappings. Respond in maximum 3 sentences."}
    ]
  }'
```

---

## 8. Stopping Jobs (IMPORTANT)

When finished, free the GPU.

```bash
scancel 156895
```

(Check job ID with `squeue -u mdipanfilo`.)

---

## 9. Adding and Deleting Models in Ollama

On the HPC cluster, **Ollama cannot be run on the login node**.  
All model management (adding or deleting models) must therefore be done via **Slurm batch jobs**.

The repository provides two dedicated batch scripts:

- `add_model.batch` → download and test a model
- `delete_model.batch` → delete a model (or list remaining ones)

All models are stored in:

```text
/data/users/mdipanfilo/ollama
```

---

### 9.1 Adding a Model

To add a new model, submit `add_model.batch` and pass the model name via `sbatch`.

```bash
cd ~/ollama-hpc/unibz
mkdir -p logs
sbatch --export=MODEL=<model_name> add_model.batch
```

**Examples:**

```bash
sbatch --export=MODEL=deepseek-r1:8b add_model.batch
sbatch --export=MODEL=llama3.1:8b add_model.batch
```

What the script does:
1. Starts an Ollama server on a GPU node
2. Pulls the requested model
3. Runs a simple test query using `ollama run`
4. Lists all installed models

An optional default model can be defined directly inside `add_model.batch`
(by uncommenting the corresponding line).

---

### 9.2 Deleting a Model

To delete a model, submit `delete_model.batch` with the model name:

```bash
cd ~/ollama-hpc/unibz
sbatch --export=MODEL=<model_name> delete_model.batch
```

**Example:**

```bash
sbatch --export=MODEL=qwen2.5:7b delete_model.batch
```

If `MODEL` is **not** provided, the script will **not delete anything** and will
only list the remaining installed models.

For safety, no default model is deleted unless explicitly specified.

---

### 9.3 Checking Progress

Monitor the job and logs as usual:

```bash
squeue -u mdipanfilo
tail -f logs/<JOBID>.out
```
## 10. Useful Commands Cheat Sheet

```bash
# Jobs
squeue -u mdipanfilo
scancel <JOBID>

# Logs
tail -f <JOBID>.out

# Ollama
ollama list
ollama pull <model>
ollama run <model>
```

---

## 11. Notes & Warnings

- Jobs may be preempted → use checkpointing if needed
- `/data` is not backed up
- Files older than 6 months in `/data` are deleted automatically
- Always cancel jobs when done

---

Happy GPU crunching 🚀
