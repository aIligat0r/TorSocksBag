# 🧅 TorSocksBag — A Docker cluster of TOR proxies

<p align="center">
  <img width="800" height="400" src="./data/banner.png">
</p>

🧅 **TorSocksBag** is a Docker project for running multiple TOR SOCKS proxies in one container at once.

The project is suitable for those who want to deploy quickly:
- TOR proxy cluster on a local machine or server
- Multiple SOCKS5 ports for distributed operation
- Support for obfuscation via OBFS4 bridges
- Automatic monitoring and restart of fallen instances

---

## ✨ Main features

- Multi-TOR instances with a separate `SocksPort` on each proxy
- Batch container assembly via `docker-compose`
- Configurable number of proxies via `.env`
- File `templates/bridges.txt ` for obfs4 bridges
- Control via `tor-manager.sh `
- Separate TOR data storage in Docker volume `tor-data`

---

## 📁 Project structure

- `docker-compose.yaml` — service and volume mounting
- `Dockerfile` — image based on `debian:stable-slim` with TOR and obfs4proxy
- `entrypoint.sh ` — launches the TOR cluster and organizes monitoring
- `tor-manager.sh ` — cluster management shell
- `.env` / `.env.Example` — basic startup parameters
- `templates/torrc.template` — TOR configuration template
- `templates/bridges.txt ` — obfs4 bridges for bypassing locks

---

## 🚀 Quick start

1. Copy the configuration example:
    ```bash
    copy .env.Example .env
    ```

2. If necessary, change the parameters in `.env`:
    - `START_PORT` — the starting port for the first SOCKS5 proxy
    - `PROXY_COUNT` — the number of TOR instances
    - `END_PORT` — end port for forwarding
    - `CONTROL_BASE_PORT` — base port for ControlPort (if enabled)
    - `ENABLE_CONTROL` — enable control via ControlPort
    - `USE_BRIDGES` — use bridges from `templates/bridges.txt `
    - `TOR_LOG_LEVEL` — logging level: `notice`, `info`, `debug`
    - `ENABLE_MONITORING` — auto-restart of crashed processes

3. Start the cluster:
    ```bash
    bash tor-manager.sh start
    ```
4. Check the status:
    ```bash
    bash tor-manager.sh status
    ```

---

## ⚙️ How it works

The container creates a 'PROXY_COUNT` of TOR instances.
Each instance listens to its SOCKS port:
- `START_PORT`
- `START_PORT + 1`
- ...
- `START_PORT + PROXY_COUNT - 1`

For example, with `START_PORT=9050` and `PROXY_COUNT=10`, ports `9050`–`9059` will be created.

`entrypoint.sh` generates a configuration for each instance and runs TOR in the background. If `ENABLE_MONITORING=true` is enabled, the process is monitored and automatically restarts when it crashes.

---

## 🔧 Configuration

### `.env`

```bash
START_PORT=9050
PROXY_COUNT=10
END_PORT=9060
CONTROL_BASE_PORT=9050
ENABLE_CONTROL=false
USE_BRIDGES=true
TOR_LOG_LEVEL=notice
ENABLE_MONITORING=true
```

### Sources of TOR bridges (`templates/bridges.txt `):
- Telegram: @GetBridgesBot
- https://bridges.torproject.org
- Email address: bridges@torproject.org (a message with the text `get transport obfs4`)

If `USE_BRIDGES=true`, the container reads bridges from `templates/bridges.txt `.


To get fresh bridges, use the services of the Tor Project or other trusted sources.

---

## 🎮 Management commands

### `tor-manager.sh`

| Team | Description |
|---|---|
| `start` | Build and launch a container in the background |
| `stop` | Stop the cluster |
| `restart` | Restart the container |
| `status` | Show the status of the container and TOR ports |
| `logs` | Monitor container logs |
| `newnym` | Request new TOR schemas (requires `ENABLE_CONTROL=true`) |
| `check` | Test all SOCKS proxies and show the IP |

### Examples

```bash
bash tor-manager.sh start
bash tor-manager.sh status
bash tor-manager.sh logs
bash tor-manager.sh check
bash tor-manager.sh newnym
```

To request new TOR chains (`NEWNM`), enable `ENABLE_CONTROL=true` and restart the container.

---

## 🧪 Proxy testing

After launching, make sure that the proxies are working.:

```bash
curl --socks5-hostname localhost:9050 https://check.torproject.org
```

Or check all ports with one command.:

```bash
bash ./tor-manager.sh check
```

Or other apps:

_Python_:
```python
import requests
from itertools import cycle

PROXIES = [
    "socks5h://127.0.0.1:9050",
    "socks5h://127.0.0.1:9051",
    "socks5h://127.0.0.1:9052",
    "socks5h://127.0.0.1:9053",
    "socks5h://127.0.0.1:9054",
    "socks5h://127.0.0.1:9055",
    "socks5h://127.0.0.1:9056",
    "socks5h://127.0.0.1:9057",
    "socks5h://127.0.0.1:9058",
    "socks5h://127.0.0.1:9059",
]
proxy_pool = cycle(PROXIES)

def fetch_with_rotation(url):
    proxy = next(proxy_pool)
    try:
        response = requests.get(
            url, 
            proxies={"http": proxy, "https": proxy},
            timeout=15
        )
        return response.text, proxy
    except Exception as err:
        print(f"Error {proxy}: {err}")
        return None, proxy

if __name__ == "__main__":
    for i in range(5):
        html, used_proxy = fetch_with_rotation("https://httpbin.org/ip")
        print(f"Request {i+1}: {used_proxy}")
        print(html[:200] if html else "Failed")
```
---

## 🐳 Docker Compose and volumes

`docker-compose.yaml`mounts:
- `./templates/bridges.txt ` → `/etc/tor/bridges.txt `
- volume `tor-data` → `/var/lib/tor`

This ensures that the TOR data is saved when the container is restarted.

---

## 🛡️ Safety and recommendations

- `ENABLE_CONTROL=false` by default to close _ControlPort from external access.
- If you use bridges, make sure that `templates/bridges.txt ` contains only verified obfs4 addresses.
- `Sandbox 0` is disabled in the configuration for compatibility inside the container.
- We recommend running the project on a separate trusted host if you are working with TOR in production.

---

## 💡 Tips for improvement

- You can add your own bridges to `templates/bridges.txt `
- Change `TOR_LOG_LEVEL` to `info` for more detailed logging
- Increase the `PROXY_COUNT` to `100` for a large proxy pool
- Connect each SOCKS port in a separate application to balance the load

---

<p align="right">
<b>Enjoying the tool? Drop a Star. Thanks and good luck!</b>
</p>

## 📜 License
MIT License
