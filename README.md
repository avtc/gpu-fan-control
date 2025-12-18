# GPU Fan Control

A Bash script that automatically controls NVIDIA GPU fan speeds based on temperature thresholds. The script monitors GPU temperatures and adjusts fan speeds accordingly to maintain optimal cooling while minimizing noise. Supports multi-fan GPUs.

## Features

- Automatic GPU-to-fan mapping using nvidia-settings verbose output
- Temperature-based fan curve with configurable thresholds
- Support for multiple GPUs and their associated fans
- Runs continuously in the background with 5-second intervals
- Minimal resource usage

## Requirements

- NVIDIA GPU with proprietary drivers installed
- `nvidia-settings` utility (part of the NVIDIA driver package)
- Linux system with systemd (Ubuntu 20.04+, Kubuntu 24.04+, etc.)
- Root/sudo privileges for fan control

## Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/avtc/gpu-fan-control.git
cd gpu-fan-control
```

### Step 2: Make the Script Executable

```bash
chmod +x gpu-fan-control.sh
```

### Step 3: Create a Systemd Service

The most robust way to run the fan control script permanently is to create a systemd service. This ensures the script starts automatically on boot and restarts if it fails.

1. **Create the service file:**
```bash
sudo nano /etc/systemd/system/gpu-fan-control.service
```

2. **Paste the following content into the file:**
```ini
[Unit]
Description=NVIDIA GPU Fan Control Script
After=network.target multi-user.target graphical.target nvidia-persistenced.service

[Service]
Type=simple
ExecStart=/path/to/your/gpu-fan-control/gpu-fan-control.sh
Restart=on-failure
RestartSec=10
User=root
Group=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**Important:** Replace `/path/to/your/gpu-fan-control/gpu-fan-control.sh` with the actual absolute path where you cloned the repository (e.g., `/home/username/gpu-fan-control/gpu-fan-control.sh`).

3. **Save the file:**
Press `Ctrl+O`, then `Enter`, then `Ctrl+X` to exit nano.

### Step 4: Enable and Start the Service

1. **Reload the systemd daemon:**
```bash
sudo systemctl daemon-reload
```

2. **Enable the service to start on boot:**
```bash
sudo systemctl enable gpu-fan-control.service
```

3. **Start the service immediately:**
```bash
sudo systemctl start gpu-fan-control.service
```

### Step 5: Verify the Installation

1. **Check the service status:**
```bash
sudo systemctl status gpu-fan-control.service
```

You should see "Active: active (running)".

2. **View the logs:**
```bash
sudo journalctl -u gpu-fan-control.service -f
```

3. **Test after reboot:**
```bash
sudo reboot
```

After rebooting, verify the service is running:
```bash
sudo systemctl status gpu-fan-control.service
```

## Setting GPU Power Limits on Startup

For systems with multiple GPUs (like 8x RTX 3090), you may want to set power limits automatically on system startup to ensure consistent performance and thermal management. This can be achieved using a systemd service.

### Example: 8x RTX 3090 Power Limit Service

1. **Create the power limit service file:**
```bash
sudo nano /etc/systemd/system/gpu-power-limit.service
```

2. **Paste the following content into the file:**
```ini
[Unit]
Description=Set NVIDIA GPU Power Limit
After=network.target multi-user.target graphical.target
Wants=nvidia-persistenced.service
# Ensure nvidia-persistenced is started if you use it

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStartPre=/usr/bin/nvidia-smi -pm 1
# Enable persistence mode for all GPUs
ExecStart=/usr/bin/nvidia-smi -i 0 -pl 280
ExecStart=/usr/bin/nvidia-smi -i 1 -pl 280
ExecStart=/usr/bin/nvidia-smi -i 2 -pl 280
ExecStart=/usr/bin/nvidia-smi -i 3 -pl 280
ExecStart=/usr/bin/nvidia-smi -i 4 -pl 280
ExecStart=/usr/bin/nvidia-smi -i 5 -pl 280
ExecStart=/usr/bin/nvidia-smi -i 6 -pl 280
ExecStart=/usr/bin/nvidia-smi -i 7 -pl 280
# Add more ExecStart lines for additional GPUs (e.g., -i 2, -i 3, etc.)

[Install]
WantedBy=multi-user.target
```

3. **Enable and start the service:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable gpu-power-limit.service
sudo systemctl start gpu-power-limit.service
```

4. **Verify the power limits:**
```bash
nvidia-smi -q | grep "Power Limit"
```

### Customizing for Your Setup

- **Power Limit Value**: The example uses `280` watts, which is typical for RTX 3090. Adjust this value based on your GPU model and requirements.
- **GPU Count**: Modify the number of `ExecStart` lines to match your GPU count.
- **GPU Indices**: Ensure the GPU indices (`-i 0`, `-i 1`, etc.) match your actual GPU configuration.

### Important Notes

- This service sets power limits to 280W for each GPU, which is common for RTX 3090 cards
- The `ExecStartPre=/usr/bin/nvidia-smi -pm 1` line enables persistence mode for better performance
- Power limits are applied before the fan control service starts, ensuring optimal thermal management
- Adjust the power limit value according to your specific GPU model and power supply capabilities

## Fan Curve

The script uses the following temperature-to-fan-speed mapping:

| Temperature Range | Fan Speed |
|-------------------|-----------|
| < 35°C            | 20%       |
| 35-39°C           | 30%       |
| 40-49°C           | 40%       |
| 50-59°C           | 50%       |
| 60-64°C           | 60%       |
| 65-69°C           | 70%       |
| 70-79°C           | 75%       |
| 80-89°C           | 80%       |
| ≥ 90°C            | 90%       |

## Troubleshooting

### Common Issues

1. **Permission Denied:**
   - Ensure the script is executable: `chmod +x gpu-fan-control.sh`
   - Make sure the service runs as root (configured in the service file)

2. **X Authority Error:**
   - The script automatically detects the X authority file
   - If you encounter issues, ensure you're running in a graphical session

3. **NVIDIA Driver Issues:**
   - Verify `nvidia-settings` is working: `nvidia-settings -q gpus`
   - Check that the NVIDIA persistence daemon is running: `systemctl status nvidia-persistenced.service`

4. **Service Not Starting:**
   - Check the logs: `sudo journalctl -u gpu-fan-control.service -b`
   - Verify the path in `ExecStart` is correct
   - Ensure all dependencies are installed

### Manual Testing

To test the script manually before setting up the service:

```bash
sudo ./gpu-fan-control.sh
```

Press `Ctrl+C` to stop the script.

## Customization

### Modifying the Fan Curve

Edit the temperature thresholds in [`gpu-fan-control.sh`](gpu-fan-control.sh:40-58):

```bash
# Fan curve
if (( temp < 35 )); then
    speed=20
elif (( temp < 40 )); then
    speed=30
# ... add your custom thresholds here
else
    speed=90
fi
```

### Changing the Update Interval

Modify the sleep duration at the end of the main loop (line 72):

```bash
sleep 5  # Change 5 to your preferred interval in seconds
```

## Safety Notes

- This script enables manual fan control, overriding the default NVIDIA driver settings
- Monitor your GPU temperatures initially to ensure the fan curve is appropriate for your hardware
- The script includes safety limits (maximum 90% fan speed) to prevent excessive wear
- Always test in a controlled environment before deploying to production systems

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Disclaimer

This software comes with no warranty. Use at your own risk. The authors are not responsible for any damage to your hardware.