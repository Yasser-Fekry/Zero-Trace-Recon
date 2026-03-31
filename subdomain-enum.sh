#!/bin/bash

# Check if a target domain was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <domain.com>"
    exit 1
fi

DOMAIN=$1

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Create a directory for the target and navigate into it
echo "[*] Creating directory for $DOMAIN..."
mkdir -p $DOMAIN
cd $DOMAIN

echo -e "${GREEN}[+] Starting Subdomain Recon for: $DOMAIN ${NC}"

# 1. Run Subfinder
echo "[*] Running subfinder..."
subfinder -d $DOMAIN -silent -all -recursive -o subfinder_subs.txt

# 2. Amass (COMMENTED OUT)
# echo "[*] Running amass passive enum..."
# amass enum -passive -d $DOMAIN -o amass_passive_subs.txt

# 3. Scrape crt.sh
echo "[*] Scraping crt.sh..."
curl -s "https://crt.sh/?q=%25.$DOMAIN&output/json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u > crtsh_subs.txt

# 4. Aggregate results
echo "[*] Merging all found subdomains..."
cat *_subs.txt 2>/dev/null | sort -u | uniq > all_subs.txt

# 5. Check for live websites using httpx
echo "[*] Probing for live domains..."

if command -v httpx &> /dev/null; then
    # Output file renamed to httpx_output.txt as requested
    httpx -l all_subs.txt -p 80,443,8080,8443 -silent -title -sc -ip -o httpx_output.txt
    
    # Extract only the URLs (column 1)
    echo "[*] Extracting clean URLs..."
    cut -d' ' -f1 httpx_output.txt > clean_urls.txt
    
    echo -e "${GREEN}[+] Recon Complete!${NC}"
else
    echo -e "${RED}[!] Error: httpx is not installed or not in PATH.${NC}"
    exit 1
fi

echo "[+] Total subdomains found: $(cat all_subs.txt | wc -l)"
echo "[+] Live hosts saved to: httpx_output.txt"
echo "[+] Clean URLs saved to: clean_urls.txt"

# 6. Send URLs to Burp Suite
echo "------------------------------------------------"
echo -e "${RED}[!] Sending URLs to Burp Suite (Proxy: 127.0.0.1:8080)...${NC}"
echo "[!] Ensure Burp Suite is listening on port 8080"
echo "------------------------------------------------"

# Loop through clean_urls.txt and send to Burp
# We add "http://" prefix because curl needs the protocol
cat clean_urls.txt | while read url; do
    # Check if url is not empty
    if [ ! -z "$url" ]; then
        # httpx usually provides protocol, but just in case, we ensure it exists.
        # If url starts with http, use it. If not, prepend http://
        if [[ "$url" != http* ]]; then
            url="http://$url"
        fi
        
        echo "[*] Sending: $url"
        curl -s -x http://127.0.0.1:8080 "$url" &
    fi
done

echo -e "${GREEN}[+] All URLs sent to background processes.${NC}"
