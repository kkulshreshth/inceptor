#!/bin/bash
set -e

function check_dependencies() {
    local missing_dependencies=()

    if ! command -v tshark &> /dev/null; then
        missing_dependencies+=("TShark")
    fi

    if ! command -v zenity &> /dev/null; then
        missing_dependencies+=("Zenity")
    fi

    if [ ${#missing_dependencies[@]} -eq 0 ]; then
        return 0
    else
        echo -e "The following dependencies are missing:"
        for dep in "${missing_dependencies[@]}"; do
            # Using ANSI color codes for red text
            echo -e "\033[31m- $dep\033[0m"
        done
        exit 1
    fi
}

function welcome_message() {
    if zenity --question --text="Welcome to Inceptor - PCAP Analyzer =) \n Would you like to analyze a pcap file? "
    then
        return 0
    else
        echo "User chose not to proceed."
        exit 1
    fi
}

function select_pcap() {
    pcapName=$(zenity --file-selection --title="Select the pcap file you want to analyze." --file-filter="*.pcap")
    if [ -z "$pcapName" ]
    then
        echo "Error: No pcap file selected." >&2
        exit 1
    fi
    echo $pcapName
}

function create_directories() {
    mkdir -p PCAP_Analysis/{Logins,IP_Info,MAC_Addresses,Objects,Emails,HTTP_Requests,Protocols}
}

function extract_logins() {
    pcapName=$1
    tshark -r "$pcapName" | grep --color=always -i -E 'auth|denied|login|user|usr|success|psswd|pass|pw|logon|key|cipher|sum|token|pin|code|fail|correct|restrict' > ./PCAP_Analysis/Logins/possible_logins.txt
    tshark -Q -z credentials -r "$pcapName" > ./PCAP_Analysis/Logins/credentials.txt
}

function extract_ip_info() {
    pcapName=$1
    tshark -Q -r "$pcapName" -T fields -e ip.src -e ip.dst | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | sort | uniq -c | sort -n -r > ./PCAP_Analysis/IP_Info/all_addresses.txt
    tshark -Q -r "$pcapName" -T fields -e ip.src | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | sort | uniq -c | sort -n -r > ./PCAP_Analysis/IP_Info/source_addresses.txt
    tshark -Q -r "$pcapName" -T fields -e ip.dst | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | sort | uniq -c | sort -n -r > ./PCAP_Analysis/IP_Info/destination_addresses.txt
}

function extract_mac_addresses() {
    pcapName=$1
    # Run tshark to get the ethernet endpoint information
    tshark -Q -nqr "$pcapName" -z endpoints,eth | \
    
    # Format the output into CSV
    awk '
    BEGIN {
        # Print CSV header
        print "MAC Address,Total Packets,Total Bytes,Tx Packets,Tx Bytes,Rx Packets,Rx Bytes"
    }
    /^[[:space:]]*([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/ {
        # Extract and print MAC address, Total Packets, Total Bytes, Tx Packets, Tx Bytes, Rx Packets, Rx Bytes
        print $1 "," $2 "," $3 "," $4 "," $5 "," $6 "," $7
    }' > ./PCAP_Analysis/MAC_Addresses/mac_addresses.csv
}

function extract_http_requests() {
    pcapName=$1
    tshark -r "$pcapName" -Y http.request -T fields \
    -e frame.number \
    -e frame.time_epoch \
    -e http.request.method \
    -e http.request.uri \
    -e http.host \
    -e http.user_agent \
    -e http.referer \
    -e ip.src \
    -e eth.src \
    -e http.response.code \
    -E header=y \
    -E separator=, \
    -E quote=d \
    -E occurrence=f > ./PCAP_Analysis/HTTP_Requests/http_requests.csv
}

function extract_data_to_csv() {
    tshark -r "$pcapName" -T fields \
    -e frame.number \
    -e frame.time_epoch \
    -e eth.src \
    -e eth.dst \
    -e ip.src \
    -e ip.dst \
    -e ipv6.src \
    -e ipv6.dst \
    -e ip.proto \
    -e tcp.srcport \
    -e tcp.dstport \
    -e udp.srcport \
    -e udp.dstport \
    -e frame.len \
    -e _ws.col.Protocol \
    -e _ws.col.Info \
    -E header=y \
    -E separator=, \
    -E quote=d \
    -E occurrence=f > ./PCAP_Analysis/HTTP_Requests/pcap_analysis.csv
}

function extract_emails() {
    pcapName=$1
    tshark -r "$pcapName" -T fields -e frame.number -e ip.src | awk '/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b/ {print $0}' > ./PCAP_Analysis/Emails/verbose_email_packets.txt
    tshark -r "$pcapName" | grep --color=always -E "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b" > ./PCAP_Analysis/Emails/email_packets.txt
}

function extract_protocols() {
    pcapName=$1
    tshark -r "$pcapName" -T fields -e frame.protocols | sort | uniq -c | sort -n -r > ./PCAP_Analysis/Protocols/protocols.txt
}

function analyze_pcap() {
    pcapName=$1
    extract_logins "$pcapName"
    extract_ip_info "$pcapName"
    extract_mac_addresses "$pcapName"
    extract_objects "$pcapName"
    extract_emails "$pcapName"
    extract_http_requests "$pcapName"
    extract_protocols "$pcapName"
}

function cleanup() {
    # Test to see if the created files are empty (have zero bytes) with test -s
    test ! -s "./PCAP_Analysis/Emails/email_packets.txt" && rm -f "./PCAP_Analysis/Emails/email_packets.txt"
    test ! -s "./PCAP_Analysis/Emails/verbose_email_packets.txt" && rm -f "./PCAP_Analysis/Emails/verbose_email_packets.txt"
    test ! -s "./PCAP_Analysis/HTTP_Requests/http_requests.txt" && rm -f "./PCAP_Analysis/HTTP_Requests/http_requests.txt"
    test ! -s "./PCAP_Analysis/IP_Info/all_addresses.txt" && rm -f "./PCAP_Analysis/IP_Info/all_addresses.txt"
    test ! -s "./PCAP_Analysis/IP_Info/destination_addresses.txt" && rm -f "./PCAP_Analysis/IP_Info/destination_addresses.txt"
    test ! -s "./PCAP_Analysis/IP_Info/source_addresses.txt" && rm -f "./PCAP_Analysis/IP_Info/source_addresses.txt"
    test ! -s "./PCAP_Analysis/Logins/credentials.txt" && rm -f "./PCAP_Analysis/Logins/credentials.txt"
    test ! -s "./PCAP_Analysis/Logins/possible_logins.txt" && rm -f "./PCAP_Analysis/Logins/possible_logins.txt"
    test ! -s "./PCAP_Analysis/Protocols/protocols.txt" && rm -f "./PCAP_Analysis/Protocols/protocols.txt"

    # Test whether the ./PCAP_Analysis/Objects directory has any files. Delete if empty.
    if [ $(ls -A ./PCAP_Analysis/Objects | wc -l) -eq 0 ]
    then
        rm -rf ./PCAP_Analysis/Objects
    fi
}

function finish() {
    sleep 0.5
    tree -s ./PCAP_Analysis
    zenity --info --text="Pcap scan complete. All output is in the 'PCAP_Analysis' directory.\nThanks for using Inceptor!!!\nNOTE - If a directory/file is empty, the program did not find the information."
}

function progress_bar() {
    local total=$1
    local current=$2
    local filled=$((current*20/total))
    local empty=$((20-filled))
    echo -ne "\rProgress: [${filled//?/#}${empty//?/-}] $((100*current/total))%"
}

function main() {
    check_dependencies
    welcome_message
    pcapName=$(select_pcap)
    create_directories
    progress_bar 7 1
    extract_logins "$pcapName"
    progress_bar 7 2
    extract_ip_info "$pcapName"
    progress_bar 7 3
    extract_mac_addresses "$pcapName"
    progress_bar 7 4
    extract_data_to_csv "$pcapName"
    progress_bar 7 5
    extract_emails "$pcapName"
    progress_bar 7 6
    extract_http_requests "$pcapName"
    progress_bar 7 7
    extract_protocols "$pcapName"
    cleanup
    finish
}

main