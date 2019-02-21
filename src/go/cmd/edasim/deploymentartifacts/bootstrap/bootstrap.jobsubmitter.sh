#!/bin/bash
# Copyright (C) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See LICENSE-CODE in the project root for license information.
set -x

###########################################################
# on rare occasions the extension beats the user setup,
# wait until complete
###########################################################
WAIT_SECONDS=600
AZURE_HOME_DIR=/home/$LINUX_USER
function wait_azure_home_dir() {
    counter=0
    while [ ! -d $AZURE_HOME_DIR ]; do
        sleep 1
        counter=$((counter + 1))
        if [ $counter -ge $WAIT_SECONDS ]; then
            echo "directory $AZURE_HOME_DIR not available after waiting $WAIT_SECONDS seconds"
            exit 1
        fi
    done
}
echo "wait azure home dir"
wait_azure_home_dir
###########################################################

NODE_MOUNT_PREFIX="/node"
JOB_DIR="/job"
WORK_DIR="/work"
STATS_DIR="/stats"
RSYSLOG_FILE="33-jobsubmitter.conf"
JOBSUBMITTER_SERVICE=jobsubmitter
JOBSUBMITTER_SERVICE_FILE="${JOBSUBMITTER_SERVICE}.service"

if [ -z "$JOBSUBMITTER_THREAD_COUNT" ] ; then
    export JOBSUBMITTER_THREAD_COUNT=4
fi
echo $JOBSUBMITTER_THREAD_COUNT

function remove_quotes() {
        QUOTED_STR=$1; shift
        QUOTED_STR=$(sed -e 's/^"//' -e 's/"$//' <<<"$QUOTED_STR")
        QUOTED_STR=$(sed -e "s/^'//" -e "s/'\$//" <<<"$QUOTED_STR")
        echo $QUOTED_STR
}

function mount_avere() {
    COUNTER=0
    for VFXT in $(echo $NFS_IP_CSV | sed "s/,/ /g")
    do
        MOUNT_POINT="${BASE_DIR}${NODE_MOUNT_PREFIX}${COUNTER}"
        echo "Mounting to ${VFXT}:${NFS_PATH} to ${MOUNT_POINT}"
        mkdir -p $MOUNT_POINT
        # no need to write again if it is already there
        if grep -F --quiet "${VFXT}:${NFS_PATH}    ${MOUNT_POINT}" /etc/fstab; then
            echo "not updating file, already there"
        else
            echo "${VFXT}:${NFS_PATH}    ${MOUNT_POINT}    nfs hard,nointr,proto=tcp,mountproto=tcp,retry=30 0 0" >> /etc/fstab
            mount ${MOUNT_POINT}
        fi
        COUNTER=$(($COUNTER + 1))
    done
}

function copy_edasim_binaries() {
    BOOTSTRAP_PATH="$(dirname ${BASE_DIR}${NODE_MOUNT_PREFIX}0${BOOTSTRAP_SCRIPT_PATH})"
    EDASIM_BIN=$BOOTSTRAP_PATH/edasim
    cp $EDASIM_BIN/* /usr/local/bin/.
}

function get_node_csv_string() {
    WORKING_DIR=$1; shift
    COUNTER=0
    RETURN_STR=""
    for VFXT in $(echo $NFS_IP_CSV | sed "s/,/ /g")
    do
        if [ "$COUNTER" -ne "0" ]; then
            RETURN_STR="${RETURN_STR},"
        fi
	# get the mount point and record it
        MOUNT_POINT=${BASE_DIR}${NODE_MOUNT_PREFIX}${COUNTER}
        RETURN_STR="${RETURN_STR}${MOUNT_POINT}"

        # ensure the working directory exists
        TARGET_DIR=${MOUNT_POINT}${WORKING_DIR}
        mkdir -p ${TARGET_DIR}
        chown $LINUX_USER:$LINUX_USER ${TARGET_DIR}

        COUNTER=$(($COUNTER + 1))
    done
    echo $RETURN_STR
}

function write_system_files() {
    # configuration inspired by https://fabianlee.org/2017/05/21/golang-running-a-go-binary-as-a-systemd-service-on-ubuntu-16-04/
    BOOTSTRAP_PATH="$(dirname ${BASE_DIR}${NODE_MOUNT_PREFIX}0${BOOTSTRAP_SCRIPT_PATH})"

    # disable output so secrets are not printed
    set +x
    # write env file
    ENVFILE=/etc/default/edasim
    /bin/cat <<EOM >$ENVFILE
AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT
AZURE_STORAGE_ACCOUNT_KEY="$(remove_quotes $AZURE_STORAGE_ACCOUNT_KEY)"
AZURE_EVENTHUB_SENDERKEYNAME=$AZURE_EVENTHUB_SENDERKEYNAME
AZURE_EVENTHUB_SENDERKEY="$(remove_quotes $AZURE_EVENTHUB_SENDERKEY)"
AZURE_EVENTHUB_NAMESPACENAME=$AZURE_EVENTHUB_NAMESPACENAME
EOM
    chmod 600 $ENVFILE
    set -x

    # copy the systemd file and search replace users/groups/workdircsv
    SRC_FILE=$BOOTSTRAP_PATH/systemd/${JOBSUBMITTER_SERVICE_FILE}
    DST_FILE=/lib/systemd/system/${JOBSUBMITTER_SERVICE_FILE}

    cp $SRC_FILE $DST_FILE

    WORKDIRCSV=$(get_node_csv_string $WORK_DIR)
    sed -i "s/USERREPLACE/$LINUX_USER/g" $DST_FILE
    sed -i "s/GROUPREPLACE/$LINUX_USER/g" $DST_FILE
    sed -i "s/UNIQUENAMEREPLACE/$UNIQUE_NAME/g" $DST_FILE
    sed -i "s/THREADCOUNTREPLACE/$JOBSUBMITTER_THREAD_COUNT/g" $DST_FILE
    sed -i "s:WORKDIRSCSVREPLACE:$WORKDIRCSV:g" $DST_FILE

    # copy the rsyslog file
    cp $BOOTSTRAP_PATH/rsyslog/$RSYSLOG_FILE /etc/rsyslog.d/.
}

function configure_rsyslog() {
    # enable listen on port 514/TCP
    sed -i 's/^#module(load="imtcp")/module(load="imtcp")/g' /etc/rsyslog.conf
    sed -i 's/^#input(type="imtcp" port="514")/input(type="imtcp" port="514")/g' /etc/rsyslog.conf
    systemctl restart rsyslog
}

function configure_service() {
    systemctl enable ${JOBSUBMITTER_SERVICE_FILE}
    sudo systemctl start ${JOBSUBMITTER_SERVICE}
}

function configure_user() {
    # disable output so secrets are not printed
    set +x
    USER_PROFILE_FILE="${AZURE_HOME_DIR}/.profile"
    echo "export AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT" >> $USER_PROFILE_FILE
    echo "export AZURE_STORAGE_ACCOUNT_KEY=\"$(remove_quotes $AZURE_STORAGE_ACCOUNT_KEY)\"" >> $USER_PROFILE_FILE
    echo "export AZURE_EVENTHUB_SENDERKEYNAME=$AZURE_EVENTHUB_SENDERKEYNAME" >> $USER_PROFILE_FILE
    echo "export AZURE_EVENTHUB_SENDERKEY=\"$(remove_quotes $AZURE_EVENTHUB_SENDERKEY)\"" >> $USER_PROFILE_FILE
    echo "export AZURE_EVENTHUB_NAMESPACENAME=$AZURE_EVENTHUB_NAMESPACENAME" >> $USER_PROFILE_FILE
    echo "export UNIQUE_NAME=$UNIQUE_NAME" >> $USER_PROFILE_FILE
    set -x

    BOOTSTRAP_PATH="$(dirname ${BASE_DIR}${NODE_MOUNT_PREFIX}0${BOOTSTRAP_SCRIPT_PATH})"

    # write the jobrun script file
    JOBRUN_SCRIPT="${AZURE_HOME_DIR}/jobrun.sh"
    /bin/cat <<EOM >$JOBRUN_SCRIPT
#!/bin/bash
if [ "\$#" -ne 1 ]; then
    echo "ERROR missing a job run name, use a different job run for each run"
    echo ""
    echo "usage: \$0 JOB_RUN_NAME"
    exit 1
fi
jobrun -uniqueName=\$UNIQUE_NAME \\
    -jobRunName=\$1 \\
    -batchCount=4 \\
    -deleteFiles=true \\
    -jobCount=500 \\
    -mountParity=true \\
    -jobFileConfigSizeKB=384 \\
    -workStartFileConfigSizeKB=384 \\
    -workStartFileCount=3 \\
    -workCompleteFileSizeKB=384 \\
    -workCompleteFailedFileSizeKB=1024 \\
    -workFailedProbability=0.01 \\
    -workCompleteFileCount=12
EOM
    chown $LINUX_USER:$LINUX_USER $JOBRUN_SCRIPT
    chmod 755 $JOBRUN_SCRIPT

    # write the stats_collector script file
    STATS_COLLECTOR_SCRIPT="${AZURE_HOME_DIR}/stats_collector.sh"
    TARGET_DIR=${BASE_DIR}${NODE_MOUNT_PREFIX}0${STATS_DIR}
    mkdir -p ${TARGET_DIR}
    chown $LINUX_USER:$LINUX_USER ${TARGET_DIR}
    /bin/cat <<EOM >$STATS_COLLECTOR_SCRIPT
statscollector -uniqueName=\$UNIQUE_NAME -statsFilePath=${TARGET_DIR}
EOM
    chown $LINUX_USER:$LINUX_USER $STATS_COLLECTOR_SCRIPT
    chmod 755 $STATS_COLLECTOR_SCRIPT
}

function main() {
    echo "mount avere"
    mount_avere

    echo "copy edasim binaries"
    copy_edasim_binaries

    echo "write system files"
    write_system_files

    echo "configure rsyslog"
    configure_rsyslog

    echo "start the service"
    configure_service

    echo "configure user to run the stats collector"
    configure_user

    echo "installation complete"
}

main