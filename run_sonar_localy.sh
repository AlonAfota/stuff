#!/bin/bash

trap ctrl_c INT

function ctrl_c() {
        echo "** Trapped CTRL-C"
	echo "Taking Down Sonar migraion"
	sudo docker-compose -f sonar/Sonar/sonar-migration/docker-compose.yml down
        echo "Taking Down Sonar Server"
	pkill -f sonarServer
        echo "Taking Down Sonar History Worker"
	pkill -f sonarHistoryWorker
        echo "Taking Down Sonar Task Runner"
	pkill -f sonarTaskRunner
        echo "Taking Down Sonar History"	
	pkill -f sonarhistory
        echo "Taking Down Sonar Sync"
	pkill -f sonarSync
        echo "Taking Down Sonar Client"
	kill $(ps aux | grep 'npm' | awk '{print $2}')
	sleep 5
	exit
}


echo -e "\e[7mrunning sonar migration \e[27m"
sudo docker-compose -f sonar/Sonar/sonar-migration/docker-compose.yml up --build --force-recreate --renew-anon-volumes  -d
sleep 30
echo -e "\e[7mrunning sonar client \e[27m" 
cd sonar/Sonar/Sonar-Client/
nohup npm run start &
sleep 60

echo -e "\e[7mrunning Sonar Server \e[27m"
cd ../sonar-server/
nohup go run main.go exec -a sonarServer &
sleep 5

echo -e "\e[7mrunning Sonar Task Runner \e[27m"
cd ../sonar-task-runner
nohup go run main.go exec -a sonarTaskRunner &
sleep 5

echo -e "\e[7mrun Sonar History Worker \e[27m"
cd ../sonar-history-worker/
nohup go run main.go exec -a sonarHistoryWorker &
sleep 5

echo -e "\e[7mrun Sonar History \e[27m"
cd ../sonar-sync/cmd/sonar-history
nohup go run main.go exec -a sonarhistory &
sleep 5

echo -e "\e[7mrun Sonar Sync \e[27m"
cd ../sync-service/
nohup go run main.go exec -a sonarSync &
cd ../../../../../
sleep 15 


echo -e "\e[7mStarting monitoring if code change was made and restart the related service \e[27m"
sudo sysctl fs.inotify.max_user_watches=524288
while true; 
do
f=$(inotifywait -r -e modify -e create -e delete -e move sonar/ --exclude '(\.log|\.out|set_xml)')

if echo "${f}" | grep Sonar-Client ;
then
echo "Change was made in Sonar Client , restarting service"
 
elif echo "${f}" | grep sonar-migration ;
then
echo "Change was made in Sonar migraion , restarting service"
docker-compose -f sonar/Sonar/sonar-migration/docker-compose.yml down
sudo docker-compose -f sonar/Sonar/sonar-migration/docker-compose.yml up --build --force-recreate --renew-anon-volumes  -d

elif echo "${f}" | grep sonar-server ;
then
echo "Change was made in Sonar Server , restarting service"
pkill -f sonarServer
cd sonar/Sonar/sonar-server/
nohup go run main.go exec -a sonarServer &
cd ../../../

elif echo "${f}" | grep sonar-history-worker ;
then
echo "Change was made in Sonar History Worker , restarting service"
pkill -f sonarHistoryWorker
cd sonar/Sonar/sonar-history-worker/
nohup go run main.go exec -a sonarHistoryWorker &
cd ../../../
elif echo "${f}" | grep sonar-task-runner ;
then
echo "Change was made in sonar Task Runner , restarting service"
pkill -f sonarTaskRunner
cd sonar/Sonar/sonar-task-runner
nohup go run main.go exec -a sonarTaskRunner &
cd ../../../

elif echo "${f}" | grep cmd/sonar-history ;
then
echo "Change was made in Sonar History, restarting service"
pkill -f sonarhistory
cd sonar/Sonar/sonar-sync/cmd/sonar-history
nohup go run main.go exec -a sonarhistory &
cd ../../../../../

elif echo "${f}" | grep sync-service ;
then
echo "Change was made in Sonar Service , restarting service"
pkill -f sonarSync
cd sonar/Sonar/sonar-sync/cmd/sync-service/
nohup go run main.go exec -a sonarSync &
cd ../../../../../ 

fi
done

