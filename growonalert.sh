#!/bin/bash
grow_pvc_on_nearfull=${1:-"No"} 
grow_pvc_on_full=${2:-"Yes"} 
grow_rate=${3:-1.25}
grow_debug={$4:-""}

echo "Resizing on nearfull alert=${grow_pvc_on_nearfull}. Resizing on Full alert=${grow_pvc_on_full}. Expansion ratio set to ${grow_rate} times."

i=0
alertmanagerroute=$(oc get route -n openshift-monitoring | grep alertmanager-main | awk '{ print $2 }')
curl -sk -H "Authorization: Bearer $(oc sa get-token prometheus-k8s -n openshift-monitoring)"  https://${alertmanagerroute}/api/v1/alerts | jq -r '.' >./tt.txt
export total_alerts=$(cat ./tt.txt | jq '.data | length')
echo "Looping at $(date +"%Y-%m-%d %H:%M:%S")"

while true
do
    export entry=$(cat ./tt.txt | jq ".data[$i]")
    thename=$(echo $entry | jq -r '.labels.alertname')
    if [ x"${thename}" = "xPersistentVolumeUsageNearFull" ]
    then
#       echo $entry
       if [ "x${grow_pvc_on_nearfull}" = "xYes" ]
       then
          ns=$(echo $entry | jq -r '.labels.namespace')
          pvc=$(echo $entry | jq -r '.labels.persistentvolumeclaim')
          echo "Processing NearFull alert for PVC ${pvc} in namespace ${ns}"
          currentsize=$(oc get pvc ${pvc} -n ${ns} -o json | jq -r '.spec.resources.requests.storage')
          echo "PVC current size is ${currentsize}. Will be increased ${grow_rate} times." 
          if [[ "$currentsize" == *"Mi" ]]
          then
             rawsize=$(echo $currentsize | sed -e 's/Mi//g')
             unitsize="Mi"
          elif [[ "$currentsize" == *"Gi" ]]
          then
             rawsize=$(echo $currentsize | sed -e 's/Gi//g')
             unitsize="Gi"
          elif [[ "$currentsize" == *"Ti" ]]
          then
             rawsize=$(echo $currentsize | sed -e 's/Ti//g')
             unitsize="Ti"
          else
             echo "Unknown unit this PVC: ${currentsize}"
          fi
          newsize=$(echo "${rawsize} * ${grow_rate}" | bc | cut -f1 -d'.')
          if [ "${newsize}" = "${rawsize}" ]
          then
             newsize=$(( rawsize + 1 ))
             echo "New adjusted calculated size for the PVC is ${newsize}${unitsize}"
          else
             echo "New calculated size for the PVC is ${newsize}${unitsize}"
          fi
          result=$(oc patch pvc ${pvc} -n ${ns} --type json --patch  "[{ "op": "replace", "path": "/spec/resources/requests/storage", "value": "${newsize}${unitsize}" }]")
          echo ${result}
       else
          ns=$(echo $entry | jq -r '.labels.namespace')
          pvc=$(echo $entry | jq -r '.labels.persistentvolumeclaim')
          echo "NOT processing NearFull alert for PVC ${pvc} in namespace ${ns}"
       fi
    elif [ x"${thename}" = "xPersistentVolumeUsageCritical" ]
    then
#       echo $entry
       if [ "x${grow_pvc_on_full}" = "xYes" ]
       then
          ns=$(echo $entry | jq -r '.labels.namespace')
          pvc=$(echo $entry | jq -r '.labels.persistentvolumeclaim')
          echo "Processing CriticalFull alert for PVC ${pvc} in namespace ${ns}"
          currentsize=$(oc get pvc ${pvc} -n ${ns} -o json | jq -r '.spec.resources.requests.storage')
          echo "PVC current size is ${currentsize}. Will be increased ${grow_rate} times." 
          if [[ "$currentsize" == *"Mi" ]]
          then
             rawsize=$(echo $currentsize | sed -e 's/Mi//g')
             unitsize="Mi"
          elif [[ "$currentsize" == *"Gi" ]]
          then
             rawsize=$(echo $currentsize | sed -e 's/Gi//g')
             unitsize="Gi"
          elif [[ "$currentsize" == *"Ti" ]]
          then
             rawsize=$(echo $currentsize | sed -e 's/Ti//g')
             unitsize="Ti"
          else
             echo "Unknown unit this PVC: ${currentsize}"
          fi
          newsize=$(echo "${rawsize} * ${grow_rate}" | bc | cut -f1 -d'.')
          if [ "${newsize}" = "${rawsize}" ]
          then
             newsize=$(( rawsize + 1 ))
             echo "New adjusted calculated size for the PVC is ${newsize}${unitsize}"
          else
             echo "New calculated size for the PVC is ${newsize}${unitsize}"
          fi
          result=$(oc patch pvc ${pvc} -n ${ns} --type json --patch  "[{ "op": "replace", "path": "/spec/resources/requests/storage", "value": "${newsize}${unitsize}" }]")
          echo ${result}
       else
          ns=$(echo $entry | jq -r '.labels.namespace')
          pvc=$(echo $entry | jq -r '.labels.persistentvolumeclaim')
          echo "NOT processing CriticalFull alert for PVC ${pvc} in namespace ${ns}"
       fi
    else
       if [ "x${grow_debug}" = "x-v" ]
       then
           echo "Alert ${thename} ignored"
           echo "----------"
           echo $entry
           echo "----------"
       fi
    fi
    (( i = i + 1 ))
    if (( i == total_alerts ))
    then
       sleep 300
       rm -f ./tt.txt
       alertmanagerroute=$(oc get route -n openshift-monitoring | grep alertmanager-main | awk '{ print $2 }')
       curl -sk -H "Authorization: Bearer $(oc sa get-token prometheus-k8s -n openshift-monitoring)"  https://${alertmanagerroute}/api/v1/alerts | jq -r '.' >./tt.txt
       total_alerts=$(cat ./tt.txt | jq '.data | length')
       i=0
       echo "Looping at $(date +"%Y-%m-%d %H:%M:%S")"
    fi
done

