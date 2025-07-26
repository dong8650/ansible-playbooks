import sys
import re
import yaml
import getpass
from scrapli import Scrapli
from scrapli.exceptions import ScrapliException

def load_mapping(dc):
    with open("/etc/ansible/roles/intmap/intmap.yml") as f:
        mapping = yaml.safe_load(f)
    return mapping.get(dc, {})

def extract_interface_blocks(config_text):
    pattern = r'(interface\s+\S+[\s\S]+?)(?=\n!\n|\Z)'
    return re.findall(pattern, config_text)

def convert_and_filter_interfaces(config_path, mapping):
    with open(config_path) as f:
        raw_config = f.read()

    blocks = extract_interface_blocks(raw_config)
    result = []

    for block in blocks:
        header = block.splitlines()[0]
        match = re.match(r'interface\s+(\S+)', header)
        if not match:
            continue

        real_if = match.group(1)
        if real_if in mapping:
            lab_if = mapping[real_if]
            converted = block.replace(real_if, lab_if)
            result.append(converted)

    return result

def push_config_scrapli(hostname, username, password, config_lines):
    device = {
        "host": hostname,
        "auth_username": username,
        "auth_password": password,
        "auth_strict_key": False,
        "platform": "cisco_iosxe",
        "transport": "paramiko",  # 여기 'paramiko'로 변경됨에 유의하세요
    }

    try:
        conn = Scrapli(**device)
        conn.open()
        conn.send_configs(config_lines)
        conn.close()
        print(f"[✓] {hostname}에 config 적용 완료")
    except ScrapliException as e:
        print(f"[!] Scrapli 오류: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 intconv.py /data/real-nw-backup/c8000v-dc1_real.cfg")
        sys.exit(1)

    cfg_path = sys.argv[1]
    filename = cfg_path.split("/")[-1].replace(".cfg", "")
    parts = filename.split("_")

    if len(parts) != 2:
        print(f"[!] 파일명 형식 오류: '{filename}' (예: c8000v-dc1_real.cfg)")
        sys.exit(1)

    hostname = parts[0]          # ex) c8000v-dc1
    dc = parts[1]                # ex) real

    mapping_data = load_mapping(dc)
    mapping = mapping_data.get(hostname, {})
    if not mapping:
        print(f"[!] mapping 없음: dc={dc}, hostname={hostname}")
        sys.exit(1)

    filtered_config = convert_and_filter_interfaces(cfg_path, mapping)

    print(f"[🔐] {hostname} 패스워드 입력: ", end="", flush=True)
    password = getpass.getpass("")

    push_config_scrapli(
        hostname=hostname,
        username="mins",
        password=password,
        config_lines=filtered_config
    )

