#!/bin/bash

set -e

# Function to check if a DNS record exists
check_dns_record() {
    local record_type=$1
    local record_name=$2
    curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=${record_type}&name=${record_name}" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.result[] | .id'
}

# Function to create or update DNS record
manage_dns_record() {
    local record_type=$1
    local record_name=$2
    local record_content=$3
    
    local record_id=$(check_dns_record ${record_type} ${record_name})
    
    if [ -z "$record_id" ]; then
        echo "Creating new ${record_type} record for ${record_name}..."
        curl -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data '{"type":"'${record_type}'","name":"'${record_name}'","content":"'${record_content}'","ttl":1,"proxied":false}'
    else
        echo "Updating existing ${record_type} record for ${record_name}..."
        curl -X PUT "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${record_id}" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            --data '{"type":"'${record_type}'","name":"'${record_name}'","content":"'${record_content}'","ttl":1,"proxied":false}'
    fi
}

# Ensure required environment variables are set
if [ -z "$CLOUDFLARE_ZONE_ID" ] || [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$DOMAIN" ] || [ -z "$SERVER_IP" ]; then
    echo "Error: Missing required environment variables. Please check your .env file."
    exit 1
fi

# Configure Cloudflare DNS
echo "Configuring DNS for ${DOMAIN}..."

# Manage A record for root domain
manage_dns_record "A" "${DOMAIN}" "${SERVER_IP}"

# Manage CNAME record for www subdomain
manage_dns_record "CNAME" "www.${DOMAIN}" "${DOMAIN}"

echo "DNS configuration complete!"