HPC Cluster – How To Connect & Run Experiments (Ollama)

This guide explains how to connect to the unibz ScientificNet HPC cluster, start an Ollama server on a compute node (GPU), and run experiments from your local machine via SSH port forwarding.

⸻

0. Prerequisites
	•	An active HPC account (mdipanfilo@login.hpc.scientificnet.org)
	•	SSH access configured on your local machine
	•	Basic familiarity with ssh, sbatch, and squeue
	•	Local machine with curl

Official documentation:
	•	https://hpc.scientificnet.org/help/
	•	GPU guide: https://hpc.scientificnet.org/help/guide/gpu/

⸻

1. Get the Files (Two Options)

You can either clone the repository from GitHub (recommended) or create the files manually.

⸻

Option A – Clone from GitHub (Recommended)

Clone the repository on the HPC login node:

git clone https://github.com/marcodipanfilo/ollama-hpc.git

This creates the folder:

~/ollama-hpc

Move into the unibz-specific subfolder:

cd ~/ollama-hpc/unibz

---

### Option B – Create the Files Manually

If you do **not** use GitHub, create the same directory structure manually:

```bash
mkdir -p ~/ollama-hpc/unibz
cd ~/ollama-hpc/unibz

Then create the files manually:
	•	run.batch
	•	run_example.batch

⚠️ Important:
	•	Whether you clone from GitHub or create files manually, the working directory is:

~/ollama-hpc/unibz

This ensures paths and commands are identical in both cases.

⸻

2. First-Time Setup (HPC)

2.1 Check if Ollama is installed

which ollama

If Ollama is not installed:

curl -fsSL https://ollama.com/install.sh | sh

This installs Ollama into:

$HOME/.local/bin/ollama

Make sure the path is available:

export PATH=$HOME/.local/bin:$PATH


⸻

1.2 Create directory structure

mkdir -p ~/ollama/unibz
mkdir -p /data/users/mdipanfilo/ollama

	•	~/ollama/unibz → batch scripts + node info
	•	/data/users/mdipanfilo/ollama → models (large, not backed up)

⸻

2. SSH Convenience (Recommended)

To avoid typing passwords every time, copy your local public key to the HPC login node.

2.1 On the HPC login node

cd ~/.ssh
vi authorized_keys

Paste your local public key (id_ed25519.pub) into this file.

Permissions should be:

chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys


⸻

3. Batch Scripts

You will use Slurm to start Ollama on a GPU node.

3.1 Example test batch (run_example.batch)

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

Useful for validating GPU + model download.

⸻

3.2 Production batch (run.batch)

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

This starts a persistent Ollama server on the allocated node.

⸻

4. Running Jobs

4.1 Connect to HPC

ssh mdipanfilo@login.hpc.scientificnet.org

4.2 Go to working directory

cd ~/ollama-hpc/unibz

4.3 Submit job

sbatch run.batch

Slurm returns a JOBID, e.g.:

Submitted batch job 156895


⸻

4.4 Check job status

squeue -u mdipanfilo

Example output:

JOBID   STATE   NODELIST
156895 RUNNING hpcsgn02


⸻

4.5 Inspect logs

tail -f 156895.out

(Change the file name to the job ID you see in squeue.)

⸻

5. Port Forwarding (Local → HPC GPU Node)

Once the job is RUNNING, Ollama listens on port 11434 on the compute node, not on the login node.

The batch script writes the node name to:

~/ollama/unibz/nodename.txt

5.1 Open a new local terminal

ssh -N -L 5000:$(ssh mdipanfilo@login.hpc.scientificnet.org "cat ~/ollama/unibz/nodename.txt"):11434 mdipanfilo@login.hpc.scientificnet.org

This forwards:

localhost:5000  →  GPU node :11434

Leave this terminal open.

⸻

6. Sending Requests

From your local machine:

curl -s -X POST http://localhost:5000/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model":"deepseek-r1:8b",
    "stream":false,
    "messages":[
      {"role":"user","content":"What are VKG mappings. Respond in maximum 3 sentences."}
    ]
  }'


⸻

7. Stopping Jobs (IMPORTANT)

When finished, free the GPU.

7.1 Cancel job

scancel 156895

(Check job ID with squeue -u mdipanfilo.)

⸻

8. Adding New Models to Ollama

On the HPC login node (or inside a running job):

ollama pull llama3.1:8b
ollama pull qwen2.5:7b
ollama list

Models are stored in:

/data/users/mdipanfilo/ollama


⸻

9. Useful Commands Cheat Sheet

# Jobs
squeue -u mdipanfilo
scancel <JOBID>

# Logs
tail -f <JOBID>.out

# Ollama
ollama list
ollama pull <model>
ollama run <model>


⸻

10. Notes & Warnings
	•	Jobs may be preempted → use checkpointing if needed
	•	/data is not backed up
	•	Files older than 6 months in /data are deleted automatically
	•	Always cancel jobs when done

⸻

Happy GPU crunching 🚀