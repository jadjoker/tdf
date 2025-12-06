import os
import subprocess
import tkinter as tk
from tkinter import scrolledtext, messagebox

# Use the folder this script is in as the repo root
REPO_DIR = os.path.dirname(os.path.abspath(__file__))


def run_git_command(cmd_list):
    """Run a git command in REPO_DIR and show output in the text box."""
    try:
        result = subprocess.run(
            cmd_list,
            cwd=REPO_DIR,
            capture_output=True,
            text=True
        )

        # Build a nice log entry
        output = f"$ {' '.join(cmd_list)}\n"
        if result.stdout:
            output += result.stdout
        if result.stderr:
            output += "\n[stderr]\n" + result.stderr

        output += "\n" + ("-" * 60) + "\n"

        log_box.insert(tk.END, output)
        log_box.see(tk.END)

        if result.returncode != 0:
            messagebox.showerror(
                "Git error",
                f"Command failed with code {result.returncode}. Check the log."
            )

    except FileNotFoundError:
        messagebox.showerror(
            "Git not found",
            "Git is not installed or not in your PATH.\n\n"
            "Install Git from git-scm.com and restart this script."
        )


def do_status():
    run_git_command(["git", "status"])


def do_fetch():
    run_git_command(["git", "fetch"])


def do_pull():
    run_git_command(["git", "pull"])


def do_push():
    run_git_command(["git", "push"])


def do_log():
    run_git_command(["git", "log", "--oneline", "-n", "10"])


def do_add_commit():
    msg = commit_entry.get().strip()
    if not msg:
        messagebox.showwarning("Commit message required",
                               "Please enter a commit message.")
        return

    # First add all changes
    run_git_command(["git", "add", "."])
    # Then commit
    run_git_command(["git", "commit", "-m", msg])


def do_discard_changes():
    """
    Discard all uncommitted changes in tracked files.
    Equivalent to: git restore .
    """
    answer = messagebox.askyesno(
        "Discard local changes?",
        "This will discard ALL uncommitted changes in tracked files and "
        "restore them to the last commit.\n\n"
        "Untracked files (new files not added to git) will NOT be removed.\n\n"
        "Are you sure you want to continue?"
    )
    if not answer:
        return

    run_git_command(["git", "restore", "."])


# ---- UI SETUP ----

root = tk.Tk()
root.title("TowerDefense Git Helper")

# Top frame: main git buttons
button_frame = tk.Frame(root)
button_frame.pack(fill=tk.X, padx=10, pady=5)

status_btn = tk.Button(button_frame, text="Status", command=do_status, width=10)
status_btn.pack(side=tk.LEFT, padx=2)

fetch_btn = tk.Button(button_frame, text="Fetch", command=do_fetch, width=10)
fetch_btn.pack(side=tk.LEFT, padx=2)

pull_btn = tk.Button(button_frame, text="Pull", command=do_pull, width=10)
pull_btn.pack(side=tk.LEFT, padx=2)

push_btn = tk.Button(button_frame, text="Push", command=do_push, width=10)
push_btn.pack(side=tk.LEFT, padx=2)

log_btn = tk.Button(button_frame, text="Log (10)", command=do_log, width=10)
log_btn.pack(side=tk.LEFT, padx=2)

# Middle frame: commit controls
commit_frame = tk.Frame(root)
commit_frame.pack(fill=tk.X, padx=10, pady=5)

commit_label = tk.Label(commit_frame, text="Commit message:")
commit_label.pack(side=tk.LEFT)

commit_entry = tk.Entry(commit_frame)
commit_entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=5)

commit_btn = tk.Button(commit_frame, text="Add & Commit", command=do_add_commit)
commit_btn.pack(side=tk.LEFT, padx=2)

# Safety / restore frame
safety_frame = tk.LabelFrame(root, text="Restore Options")
safety_frame.pack(fill=tk.X, padx=10, pady=5)

discard_btn = tk.Button(
    safety_frame,
    text="Discard Local Changes",
    command=do_discard_changes,
    width=20
)
discard_btn.pack(side=tk.LEFT, padx=5, pady=3)

# Bottom: log output
log_box = scrolledtext.ScrolledText(root, height=20, width=100)
log_box.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)

log_box.insert(tk.END, f"Repo: {REPO_DIR}\n" + ("-" * 60) + "\n")
log_box.configure(state=tk.NORMAL)

root.mainloop()
