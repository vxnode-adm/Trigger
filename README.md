# USB Panic Switch

A Linux-based USB monitoring dead man's switch that detects unauthorized USB devices and triggers an emergency response.

## Features

* USB device whitelist system
* Automatic USB monitoring via cron
* Detection based on USB serial numbers
* LUKS encrypted volume suspension
* Emergency shutdown trigger
* Automatic dependency installation

---

## Installation

Make the script executable:

```bash
chmod +x Trigger.sh
```

Run as root:

```bash
sudo ./Trigger.sh
```

---

## Setup

During the first run:

1. Connect all trusted USB devices
2. Run the script
3. A whitelist will be created automatically

Whitelist location:

```bash
/etc/usb-panic/whitelist.conf
```

The script also configures a cron job to monitor USB devices every **5 minutes**.

---

## Usage

### Initial Setup

```bash
sudo ./Trigger.sh
```

### Add a New Trusted USB Device

```bash
sudo ./Trigger.sh --new
```

### Manual Check

```bash
sudo ./Trigger.sh --check
```

---

## How It Works

The script compares connected USB device serial numbers against a whitelist.

If an unknown USB device is detected:

1. Active LUKS devices are suspended (`cryptsetup luksSuspend`)
2. Temporary files, logs, and shell history may be cleaned
3. The system immediately powers off

---

## Requirements

* Bash
* `cryptsetup`
* `secure-delete`
* `wipe`
* `cron`
* 

Most dependencies are installed automatically.

---

## Warning

This script can suspend encrypted volumes and immediately shut down the system.

Test carefully before using it on important machines.

## License

MIT
