# npa
caddy-automation-npa-script

Automation Script: remove-caddy.sh
This script will be comprehensive, ensuring all traces of Caddy are removed, and it will log its actions for transparency. It will also include checks to confirm the environment is clean after the removal process.

Make the Script Executable:
Set execute permissions:
bash

Copy
chmod +x remove-caddy.sh
Run the Script:
Execute the script as root:
bash

Copy
sudo ./remove-caddy.sh
What the Script Does
Stops and Disables the Caddy Service:
Stops the caddy service if it’s running.
Disables the service and removes the service file (/etc/systemd/system/caddy.service).
Reloads systemd to apply changes.
Removes Caddy Docker Containers:
Checks if Docker is installed.
Removes all containers with caddy in their name (running or stopped).
Removes the Caddy User and Group:
Deletes the caddy user and its home directory.
Deletes the caddy group.
Removes Caddy Directories and Files:
Deletes /etc/caddy, /var/log/caddy, and /var/lib/caddy.
Searches /home for any Caddy-related files or directories (e.g., /home/ssm-user/Caddyfile) and removes them.
Removes Caddy Entries from /etc/hosts:
Removes the application1.lan entry from /etc/hosts.
Verifies Removal:
Checks for any remaining Caddy components (service, containers, user, group, directories, /etc/hosts entries).
Reports any warnings if components are still found.
Logging:
Logs all actions to a timestamped file in /root/ (e.g., /root/caddy-removal-2025-05-22-1802.log).
Expected Output
The script will print progress messages and log them to the specified log file.
If successful, it will end with:
text

Copy
Caddy removal completed successfully at <date>.
All Caddy-related components have been removed.
Removal log saved to: /root/caddy-removal-<timestamp>.log
If any components remain, it will report warnings and exit with a non-zero status:
text

Copy
Caddy removal completed with X warnings at <date>.
Please review the warnings above and manually remove any remaining components if necessary.
Expected Timeline
May 22, 2025, 06:02 PM IST (Now): Run the script.
~2-3 minutes: The script completes.
By ~06:05 PM IST: All Caddy components should be removed.
Troubleshooting
If the script reports warnings:

Check the Log File:
View the log file for details:
bash

Copy
cat /root/caddy-removal-*.log
Manually Remove Remaining Components:
If the script identifies remaining components, follow the warnings to manually remove them. For example:
If the caddy user still exists:
bash

Copy
sudo userdel -r caddy
If /etc/caddy still exists:
bash

Copy
sudo rm -rf /etc/caddy
Rerun the Script:
After addressing warnings, rerun the script to confirm everything is removed.
