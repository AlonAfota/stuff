#!/bin/bash

echo -e "\E[1;33m Which version do you want to download ?(insert only the last 3 digit) \033[1m\033[0m"
read version 
wget http://10.40.1.179/artifactory/ivy-repos/harmonic/Sonar/trunk/1.0.0.0-eng.$version/Sonar_output.zip
unzip Sonar_output.zip
rm Sonar_output.zip
mv Sonar/output/sonar-publish/sonar-sync/ .
rm -rf Sonar/
tar -zcvf sonar-sync_$version.tar.gz sonar-sync
rm -rf sonar-sync/


probe_name=(ACCESS-COMM-LINK-1 	DNA-LINK-1 COMPORIUM-LINK-1 WESTMAN-LINK-1 ROGERS-LINK-1 TIGO-GUATEMALA-LINK-1 INTER-MOUNTAIN-LINK-1 TIGO-PARAGUAY-LINK-1 TIGO-COLOMBIA-LINK-1)
probe_array=(94-40-c9-49-72-24 48-df-37-a4-e6-70 00-50-56-91-59-8d 00-50-56-99-03-de 00-50-56-a3-66-c5 94-40-c9-49-6b-b4 d8-eb-97-b9-aa-4b fa-16-3e-d7-12-5f 00-50-56-b1-a0-40)

b=0
for i in "${probe_name[@]}"
do
        echo -e "\E[1;33m Upgrading $i \033[1m\033[0m"
        probe__id="${probe_array[b]}"
        b=$((b+1))


# Set Horizon API url here
horizon__url="https://probes.cableos-central.com/api/1"


# Auth token - normally you don't need to change it
auth_token="3b9a95980c3b2fdc71012d1bff8bf078babda10a"


# Probe/Link machine mac address - should be already registered in horizon
#prob__is is for Link of QA Lab
#probe__id="00-0c-29-35-f0-48"
echo -e "\E[1;33m Probe ID is : $probe__id \033[1m\033[0m"


# Task instance definition
# task.slug (no spaces allowed) - task identifier used in urls
task__slug="upgrade_$i""_to_$version"
# task.name - name of the task (displayed in Horizon UI)
task__name="upgrade_$i""_to_$version"



# task.script - complex execution logic - write your script here
# Comment the code block below if you don't need this field
read -d '' task__script << 'EOT'
#!/bin/bash

tar -zxvf $PHOENIX__DATADIR/sonar-sync*

sudo systemctl stop sonar-history.service
sudo systemctl stop sonar-sync.service
sudo systemctl stop sonar-fft.service

sudo rm -rf /opt/sonar/sonar-sync
sudo rm -rf /opt/sonar/sonar-history
sudo rm -rf /opt/sonar/fft-service

sudo mv sonar-sync/sonar-sync /opt/sonar/
sudo mv sonar-sync/sonar-history /opt/sonar/ 
sudo mv sonar-sync/fft-service /opt/sonar/

sudo rm -rf sonar-sync 

cp /opt/sonar/start_sync.sh /opt/sonar/sonar-sync/
cp /opt/sonar/start_history.sh  /opt/sonar/sonar-history/
cp /opt/sonar/start_fft.sh  /opt/sonar/fft-service/

sudo systemctl start sonar-history.service
sudo systemctl start sonar-sync.service
sudo systemctl start sonar-fft.service

sudo systemctl enable sonar-history.service
sudo systemctl enable sonar-sync.service
sudo systemctl enable sonar-fft.service

sleep 15
sudo systemctl status sonar-history.service
sudo systemctl status sonar-sync.service
sudo systemctl status sonar-fft.service
 
cat /opt/sonar/sonar-sync/version.txt

EOT


# task.package - path to the file you want to attach to the task
# Comment line below if you don't need the package
task__package="/home/harmonic/sonar-sync_$version.tar.gz"


function main() {
    # App entry point

    # Task creation - please check that all parameters were set correctly
    echo "Creating task ..."
    task__id=$(create_task "$task__slug" "$task__name" "$task__cmdline" "$task__script" "$task__package")
    task__id=${task__id:1:-1}
    # create_task "$task__slug" "$task__name" "$task__cmdline" "$task__script" "$task__package"
    # task__id=$?
    echo " task.id: $task__id"

    echo "  Done:"
    echo "    task.slug: $task__slug"
    echo "    task.id: $task__id"
    echo ""
    echo "  You may check appearance of new Task entity in Horizon UI:"
    echo "    $( echo $horizon__url | cut -d'/' -f1-3 )/admin/probes/task/ "
    echo ""
    echo ""


    # Task assignment
    echo "Assigning task ..."
    assignment__id=$(assign_task "$task__id" "$probe__id")
    # assign_task "$task__id" "$probe__id"
    # assignment__id=$?

    echo "  Done:"
    echo "    task.slug: $task__slug"
    echo "    probe.system_id: $probe__id"
    echo "    assignment.id: $assignment__id"
    echo ""
    echo "  You may check appearance of new Assignment entity in Horizon UI:"
    echo "    $( echo $horizon__url | cut -d'/' -f1-3 )/admin/probes/assignment/ "
    echo ""
}

function create_task() {
    # Task creation logic

    local task__slug=$1
    local task__name=$2
    local task__cmdline=$3
    local task__script=$4
    local task__package=$5

    # Appends additional curl parameter if task__package defined
    package=""
    if [ ! -z "$task__package" ]; then
        package="-F package=@$task__package"
    fi

    # Creates Task entity by sending POST request with curl.
    # You may check appearance of new Task enitity in Horizon UI:
    #    https://horizon-url/admin/probes/task/
    local response_data=$( \
      curl -s -X POST \
           -H "Authorization: Token $auth_token" \
           -H "Content-Type: multipart/form-data" \
           -F slug="$task__slug" \
           -F name="$task__name" \
           -F cmdline="$task__cmdline" \
           -F script="$task__script" \
           $package "$horizon__url/tasks/" | jq . )

    # Extracts id of just created task
    local task__id=$( jq -n "$response_data" | jq '.id' )

    # Tries to print debug info in case of error
    if [ "$task__id" == "null" ]; then
        echo "Task has not been created:"
        echo "  task.name: '$task__name'"
        echo "  task.slug: '$task__slug'"
        echo "  task.package: '$task__package'"
        echo
        echo "  Response: "
        echo "$response_data"
        exit 1
    fi
    # return $task__id
    echo $task__id
}


function assign_task() {
    # Task assignment logic

    local task__id=$1
    local probe__id=$2

    # Creates Assignment entity by sending POST request with curl.
    # You may check appearance of new Asignment enitity in Horizon UI:
    #    https://horizon-url/admin/probes/assignment/
    local response_data=$( \
        curl -s -X POST \
             -H "Authorization: Token $auth_token" \
             -H "Content-Type: multipart/form-data" \
             -F probe_id="$probe__id" \
             -F task_id=$task__id \
             "$horizon__url/assignments/" | jq . )

    # Extracts assignment id
    local assignment__id=$( jq -n "$response_data" | jq '.id' )

    # Tries to print debug info in case of error
    if [ "$assignment__id" == "null" ]; then
      echo "Task has not been assigned:"
      echo "   task.id: $task__id"
      echo "  probe.id: $probe__id"
      echo "  Response: "
      echo "$response_data"
      exit 1
    fi
    # return $assignment__id
    echo $assignment__id
}

main

done
