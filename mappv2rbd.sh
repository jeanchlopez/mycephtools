#!/bin/bash
oc get pv -o 'custom-columns=NAME:.spec.claimRef.name,PVNAME:.metadata.name,STORAGECLASS:.spec.storageClassName,VOLUMEHANDLE:.spec.csi.volumeHandle' >./pvc.lst
pvcname=$(grep $1 pvc.lst  | awk '{ print $2 }')
scname=$(grep $1 pvc.lst  | awk '{ print $3 }')
handle=$(grep $1 pvc.lst  | awk '{ print $4 }' | cut -f6- -d-)
if [ "x${handle}" == "x" ]
then
   echo "Could not find any PV name matching $1"
else
   echo "-->Found the following information for PV name $1"
   echo "   - PVC is $pvcname"
   echo "   - SC  is $scname"
   if [ "${scname}" == "ocs-storagecluster-ceph-rbd" ]
   then 
      echo "--> Verifying underlying RBD configuration"
      TOOLS_POD=$(oc get pods -n openshift-storage -l app=rook-ceph-tools -o name)
      oc rsh -n openshift-storage $TOOLS_POD rbd -p ocs-storagecluster-cephblockpool info csi-vol-${handle}
   else
      echo "PV is not backed by Red Hat Openshift Container Storage block device (RBD)"
   fi
fi
rm ./pvc.lst
