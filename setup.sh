#!/bin/bash

while true; do
    OPTION=$(whiptail --title "T-GUARD INSTALLER" --menu "Choose an option:" 20 70 13 \
                    "1" "Update System and Install Prerequisites" \
                    "2" "Install Docker" \
                    "3" "Install Wazuh (SIEM) & Deploy Agent" \
                    "4" "Install Shuffle (SOAR)" \
                    "5" "Install DFIR-IRIS (Incident Response Platform)" \
                    "6" "Install MISP (Threat Intelligence)" \
                    "7" "Integration IRIS <-> Wazuh" \
                    "8" "Integration MISP <-> Wazuh" \
                    "9" "Integration VirusTotal <-> Wazuh" \
                    "10" "Integration Shuffle <-> Wazuh" \
                    "11" "PoC/Use Case - Brute Force Detection" \
                    "12" "PoC/Use Case - Malware Detection & Response" \
                    "13" "PoC/Use Case - Web Defacement Detection" \
                    "14" "Show Module (Docker) Status" 3>&1 1>&2 2>&3)
    # Script version 1.0 updated 15 November 2023
    # Depending on the chosen option, execute the corresponding command
    case $OPTION in
    1)
        # Update System and Install Prerequisites
        sudo apt-get update -y
        sudo apt-get upgrade -y
        sudo apt-get install wget curl nano git unzip nodejs -y
        ;;
    2)
        # Install Docker
        # Check if Docker is installed
        if command -v docker > /dev/null; then
            echo "Docker is already installed."
        else
            # Install Docker
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo systemctl enable docker.service && sudo systemctl enable containerd.service
        fi
        ;;
    3)
        # Install Wazuh (SIEM) & Deploy Agent
        # Install Wazuh
        cd wazuh
        sudo docker network create shared-network
        sudo docker compose -f generate-indexer-certs.yml run --rm generator
        sudo docker compose up -d

        # Check Wazuh Status
        ## List of Docker containers to check
        containers=(
            "wazuh-wazuh.dashboard-1"
            "wazuh-wazuh.manager-1"
            "wazuh-wazuh.indexer-1"
        )
        ## Function to check if a container is running
        check_running() {
        container_name=$1
        running_status=$(sudo docker inspect --format='{{.State.Running}}' $container_name 2>/dev/null)

        if [ "$running_status" == "true" ]; then
            return 0
        else
            echo "Your Wazuh installation failed: $container_name is not running."
            exit 1
        fi
        }
        ## Check the running status of each container
        for container in "${containers[@]}"; do
        check_running $container
        done

        echo "Your Wazuh installation is success and running."

        # Deploy Wazuh Agent
        echo "Next step is deploy Wazuh Agent in this Linux machine. Please input the following parameters"
        echo "Wazuh Server IP Address:"
        read wazuh_manager
        echo "Wazuh Agent Name:"
        read agent_name
        wazuh_version=$(sudo docker images --format '{{.Repository}}:{{.Tag}}' | grep '^wazuh/wazuh-dashboard:' | cut -d':' -f2)
        wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_${wazuh_version}-1_amd64.deb \
        && sudo WAZUH_MANAGER="$wazuh_manager" WAZUH_AGENT_NAME="$agent_name" dpkg -i ./wazuh-agent_${wazuh_version}-1_amd64.deb
        sudo systemctl daemon-reload
        sudo systemctl enable wazuh-agent
        sudo systemctl start wazuh-agent
        ;;
    4)
        # Install Shuffle (SOAR)
        cd shuffle
        mkdir shuffle-database 
        sudo chown -R 1000:1000 shuffle-database
        sudo swapoff -a
        sudo docker compose up -d
        ;;
    5)
        # Install DFIR-IRIS (Incident Response Platform)
        cd iris-web
        sudo docker compose build
        sudo docker compose up -d
        ;;
    6)
        # Install MISP (Threat Intelligence)
        cd misp
        
        # Show MISP Network Configuration menu
        MISP_OPTION=$(whiptail --title "MISP Network Configuration" --menu "If you install T-Guard on:\n- Private accessed VM (PC/Desktop), choose: 1. Private IP Address\n- Public accessed VM or Cloud instances (GCP, Azure, etc.), choose: 2. Public IP Address" 20 95 5 \
                            "1" "Private IP Address" \
                            "2" "Public IP Address" 3>&1 1>&2 2>&3)
        
        if [ $? -ne 0 ]; then
        echo "Returning to main menu..."
        continue  # Go back to the main menu loop
        fi

        case $MISP_OPTION in
        1)
            IP=$(hostname -I | awk '{print $1}')
            ;;
        2)
            IP=$(curl -s ip.me -4)
            ;;
        esac

        
        sed -i "s|BASE_URL=.*|BASE_URL='https://$IP:1443'|" template.env
        cp template.env .env
        sudo docker compose up -d
        ;;
    7)
        # Integration IRIS <-> Wazuh
        CONFIG_FILE="$(pwd)/wazuh/config/wazuh_cluster/wazuh_manager.conf"
        echo "IRIS API Key:"
        read API_KEY
        sed -i "s|<api_key>.*</api_key>|<api_key>$API_KEY</api_key>|" "$CONFIG_FILE"
        sudo docker exec -i iriswebapp_db psql -U postgres -d iris_db -c "INSERT INTO user_client (id, user_id, client_id, access_level, allow_alerts) VALUES (1, 1, 1, 4, 't');"
        sudo cp wazuh/custom-integrations/custom-iris.py /var/lib/docker/volumes/wazuh_wazuh_integrations/_data/custom-iris.py
        sudo docker exec -ti wazuh-wazuh.manager-1 chown root:wazuh /var/ossec/integrations/custom-iris.py
        sudo docker exec -ti wazuh-wazuh.manager-1 chmod 750 /var/ossec/integrations/custom-iris.py
        sudo docker exec -ti wazuh-wazuh.manager-1 yum install python3-pip -y
        sudo docker exec -ti wazuh-wazuh.manager-1 pip3 install requests
        cd wazuh && sudo docker compose restart
        ;;
    8)
        # Integration MISP <-> Wazuh
        sudo cp wazuh/custom-integrations/custom-misp.py /var/lib/docker/volumes/wazuh_wazuh_integrations/_data/custom-misp.py
        sudo docker exec -ti wazuh-wazuh.manager-1 chown root:wazuh /var/ossec/integrations/custom-misp.py
        sudo docker exec -ti wazuh-wazuh.manager-1 chmod 750 /var/ossec/integrations/custom-misp.py
        sudo cp wazuh/custom-integrations/local_rules.xml /var/lib/docker/volumes/wazuh_wazuh_etc/_data/rules/local_rules.xml
        sudo docker exec -ti wazuh-wazuh.manager-1 chown wazuh:wazuh /var/ossec/etc/rules/local_rules.xml
        sudo docker exec -ti wazuh-wazuh.manager-1 chmod 550 /var/ossec/etc/rules/local_rules.xml
        cd wazuh && sudo docker compose restart
        ;;
    9)    
        # Integration VirusTotal <-> Wazuh
        # Setup Wazuh Agent
        sudo apt update
        sudo apt -y install jq
        sudo cp $(pwd)/wazuh/custom-integrations/remove-threat.sh /var/ossec/active-response/bin/
        sudo chmod 750 /var/ossec/active-response/bin/remove-threat.sh
        sudo chown root:wazuh /var/ossec/active-response/bin/remove-threat.sh
        sudo systemctl restart wazuh-agent

        # Setup Wazuh Server
        cd /wazuh/custom-integrations
        echo "VirusTotal API Key:"
        read VT_API_KEY
        sed -i "s|<api_key>.*</api_key>|<api_key>$VT_API_KEY</api_key>|" "add_vtwazuh_config.conf"
        cat add_vtwazuh_config.conf >> ../config/wazuh_cluster/wazuh_manager.conf
        cat add_vtwazuh_rules.xml >> local_rules.xml
        sudo cp local_rules.xml /var/lib/docker/volumes/wazuh_wazuh_etc/_data/rules/local_rules.xml
        sudo docker exec -ti wazuh-wazuh.manager-1 chown wazuh:wazuh /var/ossec/etc/rules/local_rules.xml
        sudo docker exec -ti wazuh-wazuh.manager-1 chmod 550 /var/ossec/etc/rules/local_rules.xml
        cd .. && sudo docker compose restart
        ;;
    10)
        # Integration Shuffle <-> Wazuh
        cd /wazuh/custom-integrations
        echo "Shuffle Hook URL:"
        read SHUFFLE_URL
        sed -i "s|<hook_url>.*</hook_url>|<hook_url>$SHUFFLE_URL</hook_url>|" "add_shufflewazuh_config.conf"
        cat add_shufflewazuh_config.conf >> ../config/wazuh_cluster/wazuh_manager.conf
        cd .. $$ sudo docker compose restart
        ;;
    11)    
        # PoC/Use Case - Brute Force Detection
        IP=$(curl -s ip.me -4)
        ssh 7d83h1@$IP

        for i in $(seq 1 10); do
            echo "Simulate Brute Force: Attempt $i..."
            ssh -o BatchMode=yes -o ConnectTimeout=5 "7d83h1@$IP"
        done
        ;;
    12)
        # PoC/Use Case - Malware Detection and Response
        sudo curl -Lo /root/eicar.com https://secure.eicar.org/eicar.com && sudo ls -lah /root/eicar.com
        ;;
    13)
        # PoC/Use Case - Web Defacement Detection
        cd usecase/slot-webdeface
        IP=$(curl -s ip.me -4)
        sudo sed -i -e "s/(your_vm_ip)/$IP/g" ./server.js
        kill $(ps aux | grep 'node server.js' | awk '{print $2}' | head -1)
        nohup node server.js > server.log 2>&1 &

        echo "Before we do webdefacement simulation, visit your website here: http://$IP:3000"
        read -p "Ready to do webdefacement?? (y/n) " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
            echo "Operation cancelled by the user."
            exit 1
        fi
        cat slotwebdeface.html > index.html
        echo "Your website defaced!! Refresh your browser."
        read -p "Do you want to recover your website? (y/n) " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]
        then
            echo "Alright then,"
            exit 1
        fi
        cat slotwebdeface.html > index.html
        echo "Your website recovered."
        ;;
    14)
        sudo docker ps
        ;;
esac
    # Give option to go back to the previous menu or exit
    if (whiptail --title "Exit" --yesno "Do you want to exit the script?" 8 78); then
        break
    else
        continue
    fi
done
