<div align="center">

```
███╗   ██╗███████╗██╗  ██╗██╗   ██╗███████╗
████╗  ██║██╔════╝╚██╗██╔╝██║   ██║██╔════╝
██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗
██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║
██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║
╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
```

**Nexus — Linux Server Manager**

![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?style=flat-square&logo=linux&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)
![Version](https://img.shields.io/badge/Version-1.2-cyan?style=flat-square)

</div>

---

## ✨ Features

| Module | Description |
|---|---|
| 🖥️ **System Manager** | Update, upgrade, cleanup packages (apt / yum / dnf) |
| 📊 **Monitoring & Diagnostics** | Live CPU, RAM, disk, network, SSH sessions |
| 🌐 **Network Configuration** | Interface info, DNS, ports, real-time bandwidth |
| 🔒 **Security & Firewall** | UFW / iptables management, Fail2Ban, port scanner |
| 👤 **User Manager** | Add/remove users, SSH key management, sudo control |
| 🎛️ **Panel & SSL** | Install panels (Nginx, Apache), Let's Encrypt SSL |
| 🤖 **Telegram Bot Panel** | Remote monitoring via Telegram bot |

---

## ⚡ Quick Install (One-liner)

```bash
bash <(curl -s https://raw.githubusercontent.com/parsa8585/nexus/main/install.sh)
```


---

## 📦 Manual Install

```bash
# Clone the repo
git clone https://github.com/parsa8585/nexus.git
cd nexus

# Make executable
chmod +x nexus.sh

# Run
sudo bash nexus.sh
```

---

## 🖼️ Preview

```
+====================================================+
|                  Nexus v1.2                        |
|                 Created by Prs                     |
+----------------------------------------------------+
|                                                    |
|  Hostname    : my-server                           |
|  IPv4        : 1.2.3.4                             |
|  IPv6        : 2001:db8::1                         |
|  Country     : Germany                             |
|  OS          : Ubuntu 22.04.3 LTS                  |
|  Kernel      : 5.15.0-91-generic                   |
|  Uptime      : 3 days, 4 hours                     |
|  Load        : 0.12                                |
|  User        : root [sudo]                         |
|                                                    |
+----------------------------------------------------+
|                                                    |
|   1.  System Manager                               |
|   2.  Monitoring & Diagnostics                     |
|   3.  Network Configuration                        |
|   4.  Security & Firewall                          |
|   5.  User Manager                                 |
|   6.  Panel & SSL                                  |
|   7.  Telegram Bot Panel                           |
|   0.  Exit                                         |
|                                                    |
+====================================================+
```

---

## 🔧 Requirements

- Linux (Ubuntu / Debian / CentOS / RHEL / Fedora)
- Bash 4.0+
- `curl` (for IP detection & Telegram bot)
- Root or sudo privileges recommended

---

## 🤖 Telegram Bot Setup

1. Talk to [@BotFather](https://t.me/BotFather) on Telegram → `/newbot`
2. Copy your bot token
3. Send `/start` to your bot, then visit:
   `https://api.telegram.org/bot<TOKEN>/getUpdates`
4. Find your `chat_id`
5. In Nexus → **Telegram Bot Panel** → option **1** → enter token & chat ID
6. Start polling → receive live server stats on Telegram

---

## 🗑️ Uninstall

```bash
sudo rm -f /usr/local/bin/nexus
```

That's it — no config files or dependencies are left behind.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">
Made with ❤️ by <strong>Prs</strong>
</div>
