
#Basic bash script to find HTTPS services, versions and vulnerabilities with nmap and metasploit


#Global variables
curr_ip="UNK"
has_http=false

#Hold IPs/Ports in a dictionary/aray
declare -A IPs
ports=()

#Dump output of a TCP connect scan across all hosts on pentest3 to readable file (mainly for ease of debugging).
#We give a host timeout time of 10 minutes, which can be rather excessive, but I've seen the host on 192.168.0.33 take up to 300 seconds to scan.
#We also scan every single port to ensure no http services are missed.
#sudo nmap -sT -n -p- 192.168.0.0/24 --host-timeout 600 > nmap_scan.txt

cat nmap_scan.txt
echo "The hosts that definetely offer HTTP(S) services are:"

#Iterate over the output file, filtering out just IPs and Ports
while read i; do
    #If the line starts with the Nmap report line, grab the IP from this line  
    if [[ $i == "Nmap scan report for 192.168.0."* ]]; then
        if [[ $curr_ip != "UNK" ]] && [[ ${#ports[@]} != 0 ]]; then

            #Save previously found ports list (by value)
            IPs[$cu rr_ip]=${ports[@]}
            ports=()
        fi

        #Grab and store the last word in the line (the IP) and reset has_http flag for new IP
        curr_ip=$(echo $i | awk '{print $NF}')
        has_http=false
    fi

    #if the line has http somewhere in it, and it isn't a standard nmap line, grab the portn number
    if [[ $i == *"http"* ]] && [[ $i != *"https://nmap.org"* ]] && [[ $i != "SF"* ]]; then
        if [[ $has_http != true ]]; then

            echo $curr_ip #Print IP to stdout
        fi

        #Filter out and grab the current port
        port=$(echo $i | awk '{print $1;}')
        ports+=(${port::-4})

        #This ensures we don't print out the IP multiple times if offering multiple HTTP services
        has_http=true
    fi

done < nmap_scan.txt

echo "" > services.txt
echo "" > vulnerabilities.txt

for IP in "${!IPs[@]}"; do

    ports=${IPs[$IP]}
    ports="${ports// /,}"

    printf "\n$IP is running the following services:\n" >> services.txt
    printf "\nnmap vulnerability scan has determined the following information for $IP:\n" >> vulnerabilities.txt

    #Use the in built nmap vulnerability scanning scripts to determine if services are vulnerable
    #Could also use searchploit but only later version of searchsploit allow version scanning/ there's a large number of false positives
    sudo nmap -sV -n $IP -p$ports --script vuln --host-timeout 600 > $IP.scan

    while read i; do
        # extract lines with names of http services, ignoring vulnerability reports and nmap debug info
        if [[ $i == *"http"* ]] && [[$i != "|"* ]] && [[ $i != *"https://nmap.org"* ]]; then
            string_arr=(${i[@]})

            #If nmap can't work out the service
            if [[ ${#string_arr[@]} == 3 ]]; then
                service=("Service not recognised")
            else
                service=("${string_arr[@]:3}")
            fi

            #Filter out and grab the current port
            port=$(echo $i | awk '{print $1;}')
            port=(${port::-4})

            echo "${service[@]} on port $port" >> services.txt
        fi

        if [[ $i == "|"* ]]; then

            if [[ $port != "-1" ]]; then
                echo "Vulnerabilities found for port: $port" >> vulnerabilities.txt
                port="-1"
            fi

            echo $i >> vulnerabilities.txt
        fi
    done < $IP.scan

    #rm $IP.scan
done

#rm nmap_scan.txt


