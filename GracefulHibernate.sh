#!/usr/bin/env bash

# Saves bash history for remote SSH sessions prior to hibernating
# 
# Gets a list of SSH sessions 
# Gets a list of all bash login sessions that are child processes of those sessions
# Sends a HUP signal to all remote bash login sessions
# Finally: hibernate



# Flush current shell history to histfile:
history -a

# Get a list of SSH sessions and store in an array
ssh_sessions=($(pgrep -af sshd | awk '{print $1}'))

# Initialize an array to store Bash session PIDs
bash_session_pids=()

# Iterate over each SSH session
for ssh_session in "${ssh_sessions[@]}"; do
    # Find child processes (likely Bash sessions) of the SSH session and store in an array
    bash_sessions=($(pgrep -af --parent "$ssh_session" | grep -E '\s+(-bash$|bash[^\;]*--login$)' | awk '$1 != "root" {print $1}'))

    # Add Bash session PIDs to the array
    bash_session_pids+=("${bash_sessions[@]}")
done


for aBashPid in "${BASH_PIDS[@]}"; do
    # Send `Hangup` signal to process.
    kill -HUP ${aBashPid}

    # Wait for bash process to flush history to `histfile`
    #   Use built-in `SECONDS` as a timeout
    SECONDS=0;
    while [[ $SECONDS -lt 15 ]] && kill -0 ${aBashPid} 2> /dev/null; do
        sleep 1;
    done

done

# Reload history from disk
# (ensures that the hisorty data just appended by HUP-ed sessions isn't overwritten)
history -r

# Finally: Hibernate
systemctl hibernate
