#! /bin/bash
# Written by 2025-07-10

This script is intended to be used with iVentoy to make setting up a chainloaded environment less problematic.
Any illicit use is strictly prohibited!

# A helper for backuping up and restoring the configuration of iVentoy for the purposes of making migrations
# from container to VM easier. Additionally, it proved helpful in trying to get chainloading working from
# FOG into iVentoy while trying to figure out what the settings needed to be.

# Note: this will reset any configuration changes made since the clean data was stored. If you add any isos or
# make any configurations, ensure you perform a new backup or you will lose your changed configurations!


VTYPTH="/etc/iventoy"
CLEAN="$VTYPTH/data_clean"
BKP="$VTYPTH/data_clean_bkp"

echo "Ventoy path is set to: $VTYPTH"

test_sudo() {
    if sudo -v; then
        echo "  Sudo access granted..."
    else
        echo "  Failed to grant sudo. Aborting!"
        exit 9
    fi
}

backup() { # codes 10-19
    echo "Performing backup operation"

    test_sudo
    sudo $VTYPTH/iventoy.sh stop

    # data_clean => data_clean_bkp (if exists)
    if [ -d "$CLEAN" ] && [ "$(ls -A "$CLEAN")" ]; then
        mkdir -p $BKP
        rm -f $BKP/*
        cp $CLEAN/* $BKP/ -v
    fi

    # data => data_clean
    mkdir -p $CLEAN
    rm -f $CLEAN/*
    cp $VTYPTH/data/* $CLEAN/ -v

    sudo $VTYPTH/iventoy.sh -R start
}

restore() { # codes 20-29
    echo "Performing restore operation..."

    if [ -d "$CLEAN" ] && [ "$(ls -A "$CLEAN")" ]; then
        echo "  Backup path found, and contains files!"
        test_sudo
        sudo $VTYPTH/iventoy.sh stop
        rm $VTYPTH/data/* -f
        cp $CLEAN/* $VTYPTH/data/
        sudo $VTYPTH/iventoy.sh -R start
    else
        echo "  Backup path missing or empty! Aborting!"
        exit 20
    fi
}

case "$1" in
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    *)
        echo -e "\nUsage: $0 { backup | restore }\n"
        echo "backup: Saves a copy of the current 'data' to '$CLEAN', whose contents are saved to '$BKP' for safety. The contents of '$BKP' will be lost."
        echo "restore: Deletes all current configuration and copies the backed up config from '$CLEAN' to 'data'."
        exit 99
esac