# Redis Master-Slave with Sentinel Setup

This project provides a guide and scripts to set up a High Availability (HA) Redis cluster using Master-Slave replication and Sentinel monitoring.

## Local Setup Instructions

### Prerequisites
Before starting the setup, ensure you have Redis and Sentinel installed on your local machine:
* **Ubuntu/Debian:** `sudo apt install redis-server redis-sentinel`
* **MacOS:** `brew install redis`

### Configuration Changes
To run this setup locally, you must update the following in your scripts:

1. **Update Master IP:** In the provided script, change the `MasterIp` variable to your local or target IP address.
2. **Setup Directories:** Ensure you have created the necessary directories for the setup.
3. **Directory Path:** Update the directory paths in the configuration files to match your local project folder.
