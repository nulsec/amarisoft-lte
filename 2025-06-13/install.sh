#!/bin/bash
# Copyright (C) 2012-2025 Amarisoft
# OTS installer version 2025-06-13

VERSION="2025-06-13"

# Options default values
INSTALL_PATH=
SRV_INSTALL=
USE_DEFAULT=
VERBOSE=
KEEP_IDIR_CHOICE="Yn"
USER="root"         # Unix user for LTE service
USERDIR="/root"     # Unix user home directory
IDIR="/root"        # Installation directory
ONLY=""
USE_SMP="n"
SKIP_PACKAGE="n"
CLEAN=""
CLEAN_OLD_VERSION=""
CLEAN_KEEP_COUNT="6"
SAVE_DIR=".save"
DRY_RUN="n"
ROOT_ON="y"
UNBRAND=""
DISK_SPACE_MIN="50000" # K

function usage
{
    if [ "$1" != "" ] ; then
        echo "$1"
    fi

    echo "
Usage:
    $0 [options] [<install path (default is $IDIR)>]

Where options:
    --default
        Force answer to default for all questions.
    --[no-]<comp>
        Install/do not install component.
        Components: $COMP_LIST
    --[no-]<comp>-autostart
        LTE service does [not] start component automatically.
        Components: $COMP_LIST
    --[no-]srv
        Force answer yes/no to the enabling of lte service. Question will be asked otherwise.
    --[no-]nat
        Force to yes/no to NAT use.
    --[no-]ipv6
        Force to yes/no to IPv6 use.
    --[no-]ipv6-nat
        Force to yes/no to use NAT for IPv6.
    --[no-]ht
        Force enabling/disabling of CPU hyperthreading (if available on system).
    --trx <name>
        Force installation of trx.
        Available frontends: $TRX_FE
    --trx-force-upgrade
        Allow downgrade of firmware (SDR only)
    --trx-no-upgrade
        Disable upgrade of firmware (SDR only)
    --[no-]mimo
        Force yes/no to MIMO use.
    --user <user>
        Install and use with user <user> (default is root).
    --no-package
        Don't install any package
    --no-clean
        Don't clean old versions
    --no-all
        Do not install any component
    --clean-keep-count
        Set how many old version to keep if (default = 6), --no-clean is not set
    --no-license-update
        Don't update license files
    --[no-]mod-<module>
        Remove (or not) kernel module black listing
    --[no]-migrate
        Enable/disable configuration files migration
    -r,--remote [<user>@]<host>
        Install remotely via SSH (We recommend to use SSH keys)
        Use localhost to also install locally.
        This option may be added several times.
        All subsequent parameters will be applied to this host only
    --target <target>
        Force target: can be linux (x86), aarch64, e310 (ARM32).
    --smp
        Use parallel installation when multiple hosts have been defined
        via -r options.
    --product <product>
        Forces Amarisoft product reference.
    --cfg <file>
        Add predefined command line arguments from a file (multi line allowed).
    -v
        Verbose mode.
    -h (--help)
        Show this help text.

    " >&2
    exit 1
}

ERROR_COUNT="0"
function Error
{
    ERROR_COUNT=$(($ERROR_COUNT + 1))
    echo -e "\033[91m$1\033[0m"
}

function untar
{
    tar xzf $1 --warning=no-timestamp
    if [ "$UNBRAND" != "" ] ; then
        local DIR=$(echo "$1" | sed -e 's/\.tar\.gz$//')
        local FILES=$(find $DIR -type f | xargs echo)
        cmd "UNBRAND" "./unbrand.pl -b $UNBRAND" $FILES
    fi
}

function UpdateWWW
{
    if [ "$WWW_PATH" = "" ] ; then
        for d in "/var/www/html" "/var/www/" ; do
            if [ -d "$d" ] ; then
                WWW_PATH="$d"
                break
            fi
        done
    fi
}

cd $(dirname $(readlink -f $0))

function CheckYesNo
{
    local arg="$1"
    local suffix="$2"
    local VAR="$3"
    local LIST="$4"

    # Yes or no ?
    if [ "${arg:0:5}" = "--no-" ] ; then
        value="n"
        arg=${arg:5}
    else
        value="y"
        arg=${arg:2}
    fi

    ARG=$(echo "${arg}" | tr '[:lower:]' '[:upper:]')
    if [ "$suffix" != "" ] ; then
        ARG=${ARG:0:-${#suffix}}
    fi

    # Look for argument in list
    for a in $(echo "$LIST" | tr '[:lower:]' '[:upper:]'); do
        if [ "$a" = "$ARG" ] ; then
            ARG=$(echo "$ARG" | sed -e "s/-/_/g")
            eval "${ARG}_${VAR}=\"$value\""
            return
        fi
    done
    usage "Invalid argument: $1"
}

# First parsing:
#   - Expand arguments with --cfg <file>
#   - Set remote
MAIN_ARGS=()
HOST_NAME=""
declare -A HOST_LIST

function ExpandArgs
{
    while [ "$1" != "" ] ; do

        case "$1" in
        --cfg)
            shift
            local args=($(cat "$1"))
            ExpandArgs "${args[@]}"
            ;;
        -r|--remote)
            shift
            AddHost $1
            ;;
        --smp)
            USE_SMP="y"
            ;;
        --target)
            TARGET="$2"
            MAIN_ARGS+=("$1" "$2")
            shift
            ;;
        *)
            #echo "? $1"
            if [ "$HOST_NAME" != "" ] ; then
                HOST_ARGS+=("$1")
            else
                MAIN_ARGS+=("$1")
            fi
        esac
        shift
    done
}

function ParseArgs
{
    while [ "$1" != "" ] ; do
        case $1 in
        --default)
            USE_DEFAULT="y"
            ;;
        --trx)
            shift
            for i in $TRX_FE ; do
                if [ "$i" = "$1" ] ; then
                    TRX_FORCED="$1"
                    break
                fi
            done
            if [ "$TRX_FORCED" = "" ] ; then
                if [ "$TRX_FE" != "" ] ; then
                    echo "TRX driver $1 not found, available drivers are: $TRX_FE"
                else
                    echo "TRX driver $1 not found, no driver available."
                fi
                exit 1
            fi
            ;;
        --no-trx)
            TRX_LIST=""
            TRX_FE=""
            ;;
        --trx-force-upgrade)
            TRX_sdr_OPT+=" --force-upgrade"
            ;;
        --trx-no-upgrade)
            TRX_sdr_OPT+=" --no-upgrade"
            ;;
        --mod-*)
            MOD=$(echo ${1:6} | tr '[:lower:]' '[:upper:]')
            eval "${MOD}_MOD_UNLOCK=y"
            ;;
        --no-mod-*)
            MOD=$(echo ${1:9} | tr '[:lower:]' '[:upper:]')
            eval "${MOD}_MOD_UNLOCK=n"
            ;;
        -v)
            VERBOSE="1"
            ;;
        --product)
            PROD_REF="$2"
            shift
            ;;
        --dry-run)
            DRY_RUN="y"
            ;;
        --user)
            shift
            USER="$1"
            USERDIR=$(eval echo ~$USER)
            IDIR="$USERDIR"
            KEEP_IDIR_CHOICE="yN"
            ;;
        --skip-root)
            ROOT_ON="n"
            MOTHERBOARD="<skip>"
            ;;
        --no-package)
            SKIP_PACKAGE="y"
            TRX_sdr_OPT+=" --no-package"
            ;;
        --no-clean)
            CLEAN="n"
            ;;
        --clean-keep-count)
            CLEAN_KEEP_COUNT="$2"
            shift
            ;;
        --unbrand)
            if [ ! -e "unbrand.pl" ] ; then
                echo "Unbranding not allowed";
                exit 1
            fi
            UNBRAND="$2"
            shift
            ;;
        --no-all)
            for a in $(echo "$COMP_LIST" | tr '[:lower:]' '[:upper:]'); do
                ARG=$(echo "$a" | tr '[:lower:]' '[:upper:]')
                eval "${ARG}_INSTALL=\"n\""
            done
            ;;
        --*-autostart)
            CheckYesNo "$1" "-autostart" "AUTOSTART" "$COMP_LIST"
            ;;
        --*) # Keep it at end
            CheckYesNo "$1" "" "INSTALL" "$COMP_LIST nat ipv6 ipv6-nat srv mimo migrate license-update ht"
            ;;
        -h|--help)
            usage
            ;;
        -*)
            usage "Invalid argument: $1"
            ;;
        *)
            if [ -z "$INSTALL_PATH" ] ; then
                INSTALL_PATH="$1"
            else
                usage "Invalid argument: $1"
            fi
            ;;
        esac
        shift
    done
}

function AddHost
{
    if [ "$HOST_NAME" != "" ] ; then
        HOST_LIST[$HOST_NAME]="${HOST_ARGS[*]}"
    fi
    if [ "$1" != "" ] ; then
        HOST_NAME="$1"
        HOST_ARGS=("${MAIN_ARGS[*]}")
    else
        HOST_NAME=""
    fi
}

function InstallHost
{
    local HOST="$1"
    local ARGS="$2"
    local SRC="$3"
    local DST="$4"

    set -e
    if [ "$HOST" = "localhost" ] ; then

        echoTitle "*" "Installing Amarisoft LTE 2025-06-13 locally"

        ./install.sh $ARGS

    else

        echoTitle "*" "Installing Amarisoft LTE 2025-06-13 on $HOST"

        ssh -q $HOST "rm -Rf $DST && mkdir -p $DST"

        echo "Transfering package to $HOST. Please wait..."
        scp -Cqr $SRC $HOST:$DST
        ssh -q $HOST -t "cd $DST && ./install.sh $ARGS && rm -Rf $DST"
    fi
}

function echoTitle
{
    local CHAR="$1"
    local LEN=$(expr length "$2")

    perl -e "print \"$CHAR\" x ($LEN + 4) . \"\n\";"
    echo "* $2 *"
    perl -e "print \"$CHAR\" x ($LEN + 4) . \"\n\";"
    echo ""
}


# Expand args
ExpandArgs "$@"

# Flush last host
AddHost

# Multi install
if [ "${#HOST_LIST[@]}" != "0" ] ; then

    RET="0"
    NOW=$(date '+%Y-%m-%d-%H:%M:%S')
    SRC=$(ls $(dirname $(readlink -f $0)))
    DST="/tmp/amarisoft-$VERSION-rinstall-$NOW"

    # Then install
    if [ "$USE_SMP" = "y" ] ; then
        declare -A PID_LIST
        for host in "${!HOST_LIST[@]}" ; do
            LOG="$DST-$host.log"
            echo "Install to $host: $LOG"
            (
                InstallHost "$host" "--default ${HOST_LIST[$host]}" "$SRC" "$DST"
            ) 1>$LOG 2>&1 &
            PID_LIST[$host]=$!
        done

        for host in "${!HOST_LIST[@]}" ; do
            wait ${PID_LIST[$host]}
            if [ "$?" != "0" ] ; then
                echo -e "\033[93mWarning, installation error on $host !\033[0m"
                tail "$DST-$host.log"
                RET="1"
            else
                echo "Installation complete on $host"
            fi
        done
    else
        for host in "${!HOST_LIST[@]}" ; do
            InstallHost "$host" "${HOST_LIST[$host]}" "$SRC" "$DST"
        done
    fi

    exit $RET
fi

function question
{
    local i
    local var="$3"
    local opt_list=`echo "$2" | sed -e 's/\B/ /g'`

    # Already set ?
    if [ "${!var}" != "" ] ; then
        echo -e "$1 [$2] ${!var}"
        return
    fi

    if [ "$USE_DEFAULT" = "y" ] ; then
        for i in $opt_list ; do
            opt=`echo $i | tr '[:upper:]' '[:lower:]'`
            if [ "$opt" != "$i" ] ; then
                echo -e "$1 [$2] $opt"
                eval "$var=$opt"
                return
            fi
        done
    fi

    read -t 0.2 -n 1000 discard || true; # Flush STDIN
    echo -n -e "$1 [$2] "
    while [ true ] ; do
        read -n 1 -s $var

        eval "$var=$(echo \"${!var}\" | tr '[:upper:]' '[:lower:]')"

        for i in $opt_list ; do
            opt=`echo $i | tr '[:upper:]' '[:lower:]'`
            if [ "$opt" = "${!var}" ] ; then
                echo "$opt"
                return
            fi
            if [ "$opt" != "$i" -a "${!var}" = "" ] ; then
                echo "$opt"
                eval "$var=$opt"
                return
            fi
        done
    done
}

function choice
{
    local C
    local choice
    local txt="$1"
    local var="$2"
    local choices="$3"
    local indent=$(echo "$txt" | sed -e "s/[^ ].*//")

    # Default
    local def="${!var}"
    for choice in $choices ; do
        if [ "$def" = "" -o "${!var}" = "$choice" ] ; then
            def="$choice"
        fi
    done

    # Header
    read -t 0.2 -n 1000 discard || true ; # Flush STDIN
    echo "$txt"
    declare -a A=({1..9} {a..z})
    local i=0
    for choice in $choices ; do
        local ctxt=$(echo $choice | sed -e "s/_/ /g")
        local a=${A[$i]}
        if [ "$def" = "$choice" ] ; then
            echo "$indent  $a) $ctxt (default)"
            local defC="$a"
        else
            echo "$indent  $a) $ctxt"
        fi
        i=$(( i + 1 ))
    done

    echo -n "$indent  > "
    while [ true ] ; do
        if [ "$USE_DEFAULT" = "y" ] ; then
            C=""
        else
            read -n 1 -s C
        fi

        if [ "$C" = "" -a "$defC" != "" ] ; then
            echo "$defC ($def)"
            eval "$var=\"$def\""
            return
        fi

        local i=0
        for choice in $choices ; do
            if [ "${A[$i]}" = "$C" ] ; then
                echo "$C ($choice)"
                eval "$var=\"$choice\""
                return
            fi
            i=$(( i + 1 ))
        done
    done
}

function prompt
{
    while [ true ] ; do
        read -t 0.2 -n 1000 discard || true; # Flush STDIN
        echo -e "$1"
        read -p "    > " "$2"

        if [ "${!2}" != "" -o "$3" = "null" ] ; then
            break;
        fi
    done
}
function ParseProduct
{
    ResetProduct
    if [[ $1 =~ ([A-Z]+)-([0-9]{8})([0-9]{2}) ]] ; then
        PROD_MODEL="${BASH_REMATCH[1]}"
        PROD_DATE="${BASH_REMATCH[2]}"
        PROD_REV="${BASH_REMATCH[3]}"
    fi
}

function ResetProduct
{
    PROD_MODEL=""
    PROD_DATE=""
    PROD_REV=""
    PROD_NAME=""
}

function UpdateProduct
{
    if [ "$MOTHERBOARD" = "" ] ; then
        DMIDECODE=$(which dmidecode)
        if [ "$DMIDECODE" ] ; then
            MOTHERBOARD=$($DMIDECODE -t 2 2>/dev/null | grep -P "Manufacturer:|Product Name:" | cut -d ':' -f2 | sed -e 's/^\s*//' | xargs echo)
        else
            MOTHERBOARD="Unknown"
        fi
    fi

    # Amarisoft products
    if [ "$PROD_REF" = "" ] ; then
        if [ -e "/etc/.amarisoft-product/hostname" ] ; then
            PROD_REF="$(cat /etc/.amarisoft-product/hostname)"
        else
            PROD_REF="$(hostname)"
        fi
        if [ -e "/etc/.amarisoft-product/host-id" ] ; then
            PROD_HOSTID="$(cat /etc/.amarisoft-product/host-id)"
        fi
        if [ -e "/etc/.amarisoft-product/dongle-id" ] ; then
            PROD_DONGLEID="$(cat /etc/.amarisoft-product/dongle-id)"
        fi
    fi

    ParseProduct "$PROD_REF"
    if [ "$PROD_MODEL" = "" ] ; then return; fi

    case "$PROD_MODEL" in
    UESB)
        PROD_NAME="UE Simbox"
        SDR_COUNT="4"
        if [ "$MOTHERBOARD" = "ASRockRack X299 WS/IPMI" ] ; then
            SDR_MAP="0 1 2 3"
        elif [ "$MOTHERBOARD" = "ASRockRack X299 Creator" ] ; then
            SDR_MAP="3 1 0 2"
        fi
        ;;
    UESBE)
        PROD_NAME="UE Simbox E"
        SDR_COUNT="2"
        if [ "$MOTHERBOARD" = "ASRockRack X299 WS/IPMI" ] ; then
            SDR_MAP="0 1 2 3"
        elif [ "$MOTHERBOARD" = "ASRockRack X299 Creator" ] ; then
            SDR_MAP="0 1 2 3"
        fi
        ;;
    UESBNG|UEMBS|UESBMBS)
        PROD_MODEL="UESBMBS"
        PROD_NAME="UE Simbox Macro Base Station"
        SDR_COUNT="3"
        if [ "$MOTHERBOARD" = "ASRockRack WRX80D8-2T" ] ; then
            SDR_MAP="2 3 0 1 4 5"
        fi
        ;;
    CBM)
        PROD_NAME="Callbox Mini"
        SDR_COUNT="1"
        if [ "$MOTHERBOARD" = "Shuttle Inc. XH410G" ] ; then
            SDR_MAP="0"
        elif [ "$MOTHERBOARD" = "Shuttle Inc. XH510G" ] ; then
            SDR_MAP="0"
        fi
        ;;
    CBC)
        PROD_NAME="Callbox Classic"
        SDR_COUNT="3"
        if [ "$MOTHERBOARD" = "ASRock Z790M-PLUS" ] ; then
            SDR_MAP="0 1 2"
        elif [ "$MOTHERBOARD" = "ASRock Z590M-PRO4" ] ; then
            SDR_MAP="0 2 1"
        elif [ "$MOTHERBOARD" = "ASRock Z590M-PLUS/Z490M-PLUS" ] ; then
            SDR_MAP="0 1 2"
        fi
        ;;
    CBP)
        PROD_NAME="Callbox Pro"
        SDR_COUNT="6"
        if [ "$MOTHERBOARD" = "ASRockRack OC Formula" ] ; then
            SDR_MAP="5 0 4 3 2 1"
        fi
        ;;
    CBU)
        PROD_NAME="Callbox Ultimate"
        SDR_COUNT="4"
        if [ "$MOTHERBOARD" = "ASRockRack X299 WS/IPMI" ] ; then
            SDR_MAP="0 1 2 3 4 5 6 7"
        elif [ "$MOTHERBOARD" = "ASRockRack OC Formula" ] ; then
            SDR_MAP="4 5 2 3 0 1 6 7"
        elif [ "$MOTHERBOARD" = "ASRockRack X299 Creator" ] ; then
            SDR_MAP="2 3 6 7 0 1 4 5"
        fi
        ;;
    CBX|CBE)
        PROD_MODEL="CBX"
        PROD_NAME="Callbox Extreme"
        SDR_COUNT="6"
        if [ "$MOTHERBOARD" = "ASRockRack WRX80D8-2T" ] ; then
            SDR_MAP="2 3 0 1 10 11 8 9 4 5 6 7"
        fi
        ;;
    CBA)
        PROD_NAME="Callbox Advanced"
        SDR_COUNT="2"
        if [ "$MOTHERBOARD" = "ASRockRack X299 WS/IPMI" ] ; then
            SDR_MAP="0 1 2 3"
        fi
        ;;
    XXX)
        ResetProduct
        if [ "$SCRIPT_SILENT" != "1" ] ; then
            echo -e "\033[94mRecovery image found\033[0m"
        fi
        return
        ;;
    *)
        PROD_NAME="$PROD_MODEL"
        ;;
    esac
    if [ "$SCRIPT_SILENT" != "1" ] ; then
        echo -e "\033[94m$PROD_NAME model found\033[0m"
    fi
}
UpdateProduct

RT_CPUSET=""
function RTCPUInit
{
    local BID=$(cat /proc/sys/kernel/random/boot_id)
    local FILE="/etc/.amarisoft-product/cpuset"
    local RT_CPUSET0="$RT_CPUSET"

    if [ -e "$FILE" ] ; then
        source "$FILE"
        if [ "$BOOT_ID" != "$BID" ] ; then
            RT_CPUSET=""
        elif [ "$RT_CPUSET0" = "" ] ; then
            Log "OTS" "Recover cpuset: $RT_CPUSET"
        fi
    fi

    local CT=$(which cyclictest)
    if [ "$CT" = "" ] ; then return; fi

    local tries="0"
    while [ "$RT_CPUSET" = "" ] ; do
        RT_CPUSET="0x0"
        local NB_LAT="0"
        Log "OTS" "Detecting CPU latency"
        while read -r line ; do
            P=$(echo "$line" | grep -Po "T:\s*\K\d+")
            if [ "$P" != "" ] ; then
                MAX=$(echo "$line" | grep -Po "Max:\s+\K\d+")
                if [[ $MAX -lt 450 ]] ; then
                    RT_CPUSET=$(perl -e "printf '0x%x', $RT_CPUSET | (1<<$P);")
                else
                    Log "OTS" "High latency detected on core $P ($MAX us)"
                    NB_LAT=$(( $NB_LAT + 1 ))
                    RT_SKIP_CORE=$P
                fi
            fi
        done < <($CT --smp -p50 -i200 -d0 -m -D8s -q)
        if [ "$NB_LAT" != "1" ] ; then
            RT_CPUSET=""
            if [[ $tries -gt 4 ]] ; then
                Log "OTS" "Can't detect high latency CPU: $NB_LAT"
                break
            fi
            tries=$(( $tries + 1 ))
            sleep 5
        else
            rm -f $FILE
            echo "# Generated on $(date -u)" > $FILE
            echo "BOOT_ID=$BID" >> $FILE
            echo "RT_CPUSET=$RT_CPUSET # !$RT_SKIP_CORE" >> $FILE
        fi
    done
}


LINUX_SERVICE=""
LINUX_PACKAGE=""
LINUX_DISTRIB="<unknown>"
LINUX_VERSION=""

if [ -e "/etc/os-release" ] ; then
    LINUX_DISTRIB=$(cat /etc/os-release | grep "^ID=" | cut -d '=' -f2 | sed -e 's/"//g')
    LINUX_VERSION=$(cat /etc/os-release | grep "^VERSION_ID=" | cut -d '=' -f2 | sed -e 's/"//g')
    LINUX_NAME=$(cat /etc/os-release | grep "^PRETTY_NAME=" | cut -d '=' -f2 | sed -e 's/"//g')
fi
if [ "$LINUX_VERSION" = "" -o "$LINUX_DISTRIB" = "" ] ; then
    if [ -e "/etc/lsb-release" ] ; then
        LINUX_DISTRIB=$(cat /etc/os-release | grep "^DISTRIB_ID=" | cut -d '=' -f2 | sed -e 's/"//g')
        LINUX_VERSION=$(cat /etc/os-release | grep "^DISTRIB_RELEASE=" | cut -d '=' -f2 | sed -e 's/"//g')
        LINUX_NAME=$(cat /etc/os-release | grep "^DISTRIB_DESCRIPTION=" | cut -d '=' -f2 | sed -e 's/"//g')
    elif [ -e "/etc/fedora-release" ]; then
        LINUX_DISTRIB="fedora"
        LINUX_VERSION=$(cat /etc/fedora-release | cut -d " " -f3)
        LINUX_NAME="Fedora"
    fi
fi

if [ "$TARGET" = "" ] ; then
    TARGET="$(uname -m)"
    if [ "$TARGET" = "x86_64" ] ; then
        TARGET="linux"
    fi
fi

LINUX_VERSION=$(echo "$LINUX_VERSION" | cut -d '.' -f1)
LINUX_DISTRIB=$(echo "$LINUX_DISTRIB" | tr '[:upper:]' '[:lower:]')

case "$LINUX_DISTRIB" in
fedora)
    if [ "$SCRIPT_SILENT" != "1" ] ; then
        echo -e "\033[94mFedora $LINUX_VERSION found\033[0m"
    fi
    if [ "$LINUX_VERSION" -gt 20 ] ; then
        LINUX_PACKAGE="dnf"
    else
        LINUX_PACKAGE="yum"
    fi
    LINUX_SERVICE="systemd"
    ;;
rhel)
    if [ "$SCRIPT_SILENT" != "1" ] ; then
        echo -e "\033[94m$LINUX_NAME found\033[0m"
    fi
    LINUX_PACKAGE="dnf"
    LINUX_SERVICE="systemd"
    ;;
ubuntu)
    if [ "$SCRIPT_SILENT" != "1" ] ; then
        echo -e "\033[94mUbuntu $LINUX_VERSION found\033[0m"
    fi
    if [ "$LINUX_VERSION" -lt "15" ] ; then
        LINUX_SERVICE="initd"
    else
        LINUX_SERVICE="systemd"
    fi
    LINUX_PACKAGE="apt"
    ;;
centos)
    if [ "$SCRIPT_SILENT" != "1" ] ; then
        echo -e "\033[94mCent OS $LINUX_VERSION found\033[0m"
    fi
    LINUX_SERVICE="systemd"
    LINUX_PACKAGE="yum"
    ;;
raspbian)
    if [ "$SCRIPT_SILENT" != "1" ] ; then
        echo -e "\033[94mRaspbian OS $LINUX_VERSION found\033[0m"
    fi
    LINUX_SERVICE="systemd"
    LINUX_PACKAGE="apt"
    ;;
debian)
    if [ "$SCRIPT_SILENT" != "1" ] ; then
        echo -e "\033[94mDebian OS $LINUX_VERSION found\033[0m"
    fi
    LINUX_SERVICE="systemd"
    LINUX_PACKAGE="apt"
    ;;
*)
    echo "Sorry, $LINUX_DISTRIB distribution not supported only available on Fedora, Ubuntu and CentOS distributions."
    exit 1
    ;;
esac

function service_cmd
{
    local name="$1"
    local cmd="$2"

    case $LINUX_SERVICE in
    systemd)
        if [ -e "/lib/systemd/system/${name}.service" ] ; then
            if [ "$VERBOSE" = "" ] ; then
                systemctl -q ${cmd} ${name} 1>/dev/null
            else
                systemctl -q ${cmd} ${name}
            fi
        fi
        ;;
    initd)
        if [ -e "/etc/init/${name}.conf" ] ; then
            if [ "$VERBOSE" = "" ] ; then
                service ${name} ${cmd} 1>/dev/null
            else
                service ${name} ${cmd}
            fi
        fi
        ;;
    esac
}

function service_install
{
    local name="$1"
    local path="$2"
    local user="$3"
    local enable="$4"

    case $LINUX_SERVICE in
    systemd)
        rm -f /lib/systemd/system/${name}.service
        cat ${path}/${name}.service | sed -e "s/<USER>/$user/" | sed -e "s'<PATH>'$path'" > /lib/systemd/system/${name}.service
        systemctl -q --system daemon-reload

        if [ "$enable" = "y" ] ; then
            systemctl -q enable ${name}
            #systemctl -q enable NetworkManager-wait-online.service
        else
            systemctl -q disable ${name}
        fi
        ;;
    initd)
        # Remove legacy
        local deamon="/etc/init.d/${name}.d"
        if [ -e "$deamon" ]; then
            $deamon stop
            update-rc.d ${name}.d disable
            rm -f $deamon
        fi

        if [ "$enable" = "y" ] ; then
            rm -f /etc/init/${name}.conf
            cat ${path}/${name}.conf | sed -e "s/<USER>/$user/" | sed -e "s'<PATH>'$path'" > /etc/init/${name}.conf
        else
            rm /etc/init/${name}.conf
        fi
        ;;
    esac
}

# Package manager state
LINUX_PACKAGE_READY="y"
function check_package_manager
{
    # Disable error
    if [[ $- =~ e ]] ; then
        ERR="1"
    fi
    set +e

    case "$LINUX_PACKAGE" in
    yum|dnf)
        # XXX
        ;;
    apt)
        LOCKED=$(lsof /var/lib/dpkg/lock 2>/dev/null)
        if [ "$LOCKED" != "" ] ; then
            LINUX_PACKAGE_READY="n"
        fi
        ;;
    esac

    # Re-enable error ?
    if [ "$ERR" = "1" ] ; then
        set -e
    fi
}
check_package_manager

function install_package
{
    if [ "$LINUX_PACKAGE" = "" ] ; then return; fi

    if [ "$(whoami)" != "root" ] ; then
        echo "\031[93mRoot access needed to install package.[0m"
        exit 1
    fi

    # Disable error
    if [[ $- =~ e ]] ; then
        ERR="1"
    fi
    set +e

    while [ "$1" != "" ] ; do
        case "$LINUX_PACKAGE" in
        yum|dnf)
            $LINUX_PACKAGE list installed $1 &>/dev/null
            if [ "$?" != "0" ] ; then
                echo "  Install package $1 (this may take a while)..."
                if [ "$VERBOSE" = "" ] ; then
                    $LINUX_PACKAGE -qq -y install $1
                else
                    $LINUX_PACKAGE -y install $1
                fi
            fi
            ;;
        apt)
            apt-cache --quiet=0 policy $1 | grep "Installed" | grep -v none &>/dev/null
            if [ "$?" != "0" ] ; then
                echo "  Install package $1 (this may take a while)..."
                if [ "$VERBOSE" = "" ] ; then
                    apt-get -qq install -y $1 &>/dev/null
                else
                    apt-get install -y $1
                fi
            fi
            ;;
        esac

        if [ "$?" != "0" ] ; then
            echo -e "  \033[93mCan't install package $1\033[0m"
            break
        fi
        shift;
    done

    # Re-enable error ?
    if [ "$ERR" = "1" ] ; then
        set -e
    fi
}

function GetHTState
{
    if [ "$HT_SYS_STATE" = "" ] ; then
        if [ -e "/sys/devices/system/cpu/smt/control" ] ; then
            HT_SYS_STATE=$(cat "/sys/devices/system/cpu/smt/control")
            if [ "$HT_SYS_STATE" = "on" ] ; then
                # Control on but only 1 thread per core
                TPC=$(lscpu | grep -oP "Thread.+per core:.+\K\d+")
                if [ "$TPC" = "1" ] ; then
                    HT_SYS_STATE="off"
                fi
            fi
        fi
    fi
}

function SetHTState
{
    echo "$1" > "/sys/devices/system/cpu/smt/control" 2>&1
}

# TRX List
# trx_<name>-<target>-<version>.tar.gz
#   TRX_<name>_FE => list of frontends (may be several per package. Ex: uhd)
#   TRX_<name>_DIR => directory
#   TRX_<name>_ARCH => archive
#   TRX_<fe>_NAME => basename of frontend
TRX_FE=""
TRX_LIST=""

COMP_LIST=""

for i in $(find . -type f -name "*-${VERSION}.tar.gz" -printf "%f\n" | sed -e "s/-${VERSION}.tar.gz//") ; do

    name=""
    if [[ ! $i =~ - ]] ; then
        name="$i"
    elif [[ $i =~ -${TARGET} ]] ; then
        name=$(echo "$i" | sed -e "s/-${TARGET}//")
    else
        continue
    fi
    DIR="${i}-${VERSION}"

    # TRX driver
    if [[ $name =~ ^trx_ ]] ; then
        if [[ $name =~ ^trx_example ]] ; then
            continue;
        fi

        TRX=${name:4}
        rm -Rf $DIR
        untar ${DIR}.tar.gz
        if [ -e "${DIR}/fe_list" ] ; then
            LIST1=$(cat ${DIR}/fe_list)
        else
            LIST1="$TRX"
        fi
        TRX_LIST+=" $TRX"
        rm -Rf $DIR
        eval "TRX_${TRX}_ARCH=\"${DIR}.tar.gz\""
        eval "TRX_${TRX}_DIR=\"${DIR}\""
        eval "TRX_${TRX}_FE=\"${LIST1}\""

        TRX_FE="$TRX_FE $LIST1"
        for j in $LIST1 ; do
            eval "TRX_${j}_NAME=\"$TRX\""
        done

    # Component
    elif [[ $name =~ ^lte ]] ; then
        c=${name:3}
        COMP=$(echo "$c" | tr '[:lower:]' '[:upper:]')

        case "$c" in
        mme)
            COMP_LIST+=" $c ims"
            ;;
        *)
            COMP_LIST+=" $c"
            ;;
        esac
        eval "${COMP}_DIR=\"${DIR}\""
        eval "${COMP}_ARCH=\"${DIR}.tar.gz\""
    fi

done

# Local
ParseArgs "${MAIN_ARGS[@]}"


# Check root
if [ "$ROOT_ON" = "y" ] ; then
    user=$(whoami)
    if [ "$user" != "root" ]; then
        echo "Sorry $user, you need to be root"
        exit 1
    fi
else
    SKIP_PACKAGE="y"
    LINUX_SERVICE=""
fi

LOG_FILE=""
if [ "$(which tee 2>/dev/null)" != "" ] ; then
    LOG_FILE="$USERDIR/.lte-install.log"
    LOG_PIPE="$USERDIR/.lte-install.pipe"

    rm -f $LOG_FILE $LOG_PIPE
    mkfifo $LOG_PIPE
    tee < $LOG_PIPE $LOG_FILE &
    exec &> $LOG_PIPE
    rm $LOG_PIPE
fi

if [ "$(which perl 2>/dev/null)" = "" ] ; then
    echo "Installation requires perl package to be installed" 1>&2
    if [ "$USER" != "root" -o "$SKIP_PACKAGE" = "y" ] ; then
        exit 1
    fi
    case "$LINUX_DISTRIB" in
    rhel|fedora)
        question "Do you want to install it ?" "Yn" "PERL"
        if [ "$PERL" = "n" ] ; then
            exit 0
        fi
        install_package perl
        ;;
    *)
        exit 1
        ;;
    esac
fi

echoTitle "*" "Installing Amarisoft LTE 2025-06-13 ($(date '+%Y-%m-%d %H:%M:%S'))"

if [ "$USER" != "root" ] ; then
    echo "Use user '$USER'";
fi

if [ "$SKIP_PACKAGE" != "y" ] ; then
    if [ "$LINUX_PACKAGE_READY" != "y" ] ; then
        echo -e "\033[91mWarning, package manager is currently locked.\033[0m"
        echo -e "Retry later or use --no-package option."
        exit 1
    fi
else
    LINUX_PACKAGE=""
fi


step=1
echo "$step) Configuration"
echo "  You can exit install script during this step, nothing will be changed"
echo "  until next step"

# Legacy ?
ETC_CFG="/etc/ltestart.conf"
if [ -e "$ETC_CFG" ] ; then
    LAST_IDIR=$(cat "$ETC_CFG" | grep -o 'IDIR=".*"' | sed -e "s/IDIR=\"\(.*\)\"/\1/")
    rm -f "$ETC_CFG"
fi

# Retreive last install information
LAST_INSTALL_FILE="$USERDIR/.lte-install"
if [ -e "$LAST_INSTALL_FILE" ] ; then
    source "$LAST_INSTALL_FILE"
fi

# Normalize
IDIR=$(readlink -f "$IDIR")

# Installation directory
if [ "$INSTALL_PATH" != "" ] ; then
    IDIR=$(readlink -f "$INSTALL_PATH")
fi
if [ "$LAST_IDIR" != "$IDIR" -a "$LAST_IDIR" != "" ] ; then
    question "  * Previous install was at $LAST_IDIR, do you want to keep previous directory (y) or use $IDIR (n) ?" "$KEEP_IDIR_CHOICE" "KEEP_IDIR"
    if [ "$KEEP_IDIR" = "y" ] ; then
        IDIR="$LAST_IDIR"
    fi
else
    LAST_IDIR="$IDIR"
fi

# Check disk space
DISK_SPACE_AVAILABLE=$(df -k "$IDIR" | tail -n 1 | awk '{print $4;}')
if [ "$DISK_SPACE_AVAILABLE" != "" ] ; then
    if [[ $DISK_SPACE_AVAILABLE -lt $DISK_SPACE_MIN ]] ; then
        echo "Not enough space on $IDIR [$(df -k "$IDIR" | tail -n 1 | awk '{print $6;}')]" >&2
        exit 1
    fi
fi

if [ ! -d "$IDIR" ] ; then
    question "  * Installation path $IDIR does not exist, do you want to create it ?" "Yn" "CREATE_INSTALL_PATH"
    if [ "$CREATE_INSTALL_PATH" != "y" ] ; then
        exit 1
    fi
fi

function SetDefault
{
    local ID="$1"
    local VAL="$2"
    local VAR="${ID}_DEFAULT"
    if [ "${!VAR}" = "" ] ; then
        eval "$VAR=\"$VAL\""
    fi
}

function StoreDefault
{
    local ID="$1"
    local VAL="$2"

    case "$VAL" in
    y)
        echo "${ID}_DEFAULT=\"Yn\"" >> $LAST_INSTALL_FILE
        ;;
    n)
        echo "${ID}_DEFAULT=\"yN\"" >> $LAST_INSTALL_FILE
        ;;
    esac
}

# Components
# => <COMP>_DIR
# => <COMP>_ARCH
# => <COMP>_NAME
# => <COMP> (If installed)
# => <COMP>_LINK
# => <COMP>_OLD_PATH (If installed)
function configure_comp
{
    local ID="$1"
    local LINK="$2"
    local NAME="$3"
    shift
    shift
    shift

    # Default value
    SetDefault "$ID" "Yn"
    local DEF="${ID}_DEFAULT"
    DEF=${!DEF}

    eval "${ID}_NAME=\"${NAME}\""
    eval "${ID}_LINK=\"${LINK}\""

    local DIR="${ID}_DIR"
    local ARCH="${ID}_ARCH"
    if [ ! -e "${!ARCH}" ] ; then return; fi

    local response="${ID}_INSTALL"
    local msg="  * Do you want to install ${NAME} ?"
    while [ "$1" != "" ] ; do
        local info="$1"
        shift
        if [ "${info:0:8}" = "package:" ] ; then
            local list=${info:8}
            info="Package ${info:8} may be installed."
            if [ "$SKIP_PACKAGE" = "y" ] ; then
                info=""
            fi
        fi
        if [ "$info" != "" ] ; then
            msg="$msg\n    $info"
        fi
    done
    question "$msg" "$DEF" "$response"
    if [ "${!response}" != "y" ] ; then return; fi

    eval "${ID}=\"${!DIR}\"" # On

    local OLD=$(readlink -f "${LAST_IDIR}/${LINK}")
    if [ -d "$OLD/config" ] ; then
        response="${ID}_MIGRATE_INSTALL"
        if [ "$MIGRATE_INSTALL" = "n" ] ; then
            eval "$response=n"
        fi
        question "      - Do you want to migrate your config files from current running version ?" "Yn" "$response"
        if [ "${!response}" = "y" ] ; then
            eval "${ID}_OLD_PATH=$OLD"
        fi
    fi
}

function configure_comp_trx
{
    local i
    local ID="$1"

    local DIR="${ID}_DIR"
    DIR="${!DIR}"

    local INS="${ID}_INSTALL"
    if [ "${!INS}" != "y" ] ; then
        return
    fi

    local FE="${ID}_FE"
    if [ "$TRX_FORCED" != "" ] ; then
        eval "${FE}=\"${TRX_FORCED}\""
        echo "      - Use ${!FE} RF frontend"
    else
        eval "${FE}=$(readlink ${LAST_IDIR}/${DIR}/config/rf_driver)"
        DEF_FE=""
        for i in $TRX_FE ; do
            if [ "${!FE}" = "$i" ] ; then
                DEF_FE="$i"
            fi
        done
        if [ "${!FE}" != "$DEF_FE" ] ; then
            echo -e "    \033[93mWarning, Current radio frontend ${!FE} not found, contact customer@amarisoft.com\033[0m"
            eval "${FE}=\"\""
        else
            # No default frontend, choose from the following list
            if [ "$DEF_FE" = "" ] ; then
                for i in sdr n2x0 b2x0 x3x0 x3x0 lms ; do
                    if [ "$(echo \"$TRX_FE\" | grep -w $i || echo "")" != "" ] ; then
                        eval "${FE}=\"$i\""
                        break
                    fi
                done
            fi
        fi
        if [ "$TRX_FE" != "" ] ; then
            choice "    - Select TRX radio frontend:" "$FE" "$TRX_FE"
        fi
    fi

    if [ "${!FE}" != "" ] ; then
        local VAR="TRX_${!FE}_NAME"
        eval "TRX_${!VAR}_INSTALL=\"y\""
    fi
}

function install_comp
{
    local ID="$1"
    local WIN="$2"

    local LINK="${ID}_LINK"
    LINK="${!LINK}"

    if [ "${!ID}" != "" ] ; then
        local DIR="${ID}_DIR"
        DIR="${!DIR}"
        local NAME="${ID}_NAME"
        echo "$step) Install ${!NAME}"
        step=$(($step+1))

        local arch="${ID}_ARCH"
        untar ${!arch}
        install_dir "${IDIR}" "$DIR" "$LINK" "${ID}_OLD_PATH"

        # TRX fronted
        local USE_TRX="n"
        local trx="${ID}_FE"
        if [ "$TRX_LIST" != "" -a "${!trx}" != "" ] ; then
            echo "  Use TRX ${!trx}"

            local VAR="TRX_${!trx}_NAME"
            local OPT="TRX_${!trx}_OPT"
            cmd "TRX" "${IDIR}/trx_${!VAR}/install.sh" ${IDIR}/${LINK} "${LINK}" "${!trx}" "${!OPT}"
            if [ "$CMD" != "0" ] ; then
                Error "    TRX ${!trx} driver installation has failed"
            else
                eval "$OPT=\"${!OPT} --no-upgrade\""
            fi
            USE_TRX="y"
        fi

        # Doc
        DOC=$(echo "$DIR" | sed -e "s/-${TARGET}//")
        if [ -d "doc/$DOC" ] ; then
            cp -r "doc/$DOC" "${IDIR}/${DIR}/doc"
        fi

        # WS
        if [ -e "libs/node_modules.tgz" ] ; then
            untar "libs/node_modules.tgz"
            mv node_modules "${IDIR}/${DIR}/"
            if [ -e "libs/ws.js" ] ; then
                cp libs/ws.js ${IDIR}/${DIR}/
            fi
            if [ "$USE_TRX" = "y" -a -e "libs/trx-iq-dump.js" ] ; then
                cp "libs/trx-iq-dump.js" "${IDIR}/${DIR}/"
            fi
        fi

        add_ots_comp "$ID" "$WIN"
    fi

    local I="${ID}_INSTALL"
    StoreDefault "$ID" "${!I}"
}

function add_ots_comp
{
    local ID="$1"
    local WIN="$2"

    local NAME="${ID}_NAME"
    local LINK="${ID}_LINK"

    AddOTSConfig "" "# ${!NAME} config"
    if [ "$WIN" != "" ] ; then
        AddOTSConfig "COMPONENTS+=\" ${ID}\"" "${ID}_TYPE=\"${ID}\"" "${ID}_WIN=\"$WIN\""
    fi
    AddOTSConfig "${ID}_PATH=\"${IDIR}/${!LINK}\""

    # Autostart
    local AUTO="${ID}_AUTOSTART"
    if [ "${!AUTO}" = "" ] ; then
        AUTO="${ID}_AUTOSTART_OLD"
    fi
    if [ "${!AUTO}" != "" ] ; then
        AddOTSConfig "${ID}_AUTOSTART=\"${!AUTO}\""
    else
        AddOTSConfig "#${ID}_AUTOSTART=\"y\""
    fi
}

function module_check
{
    local mod="$1"

    if [ "$2" = "" ] ; then return; fi

    if [ -e "/etc/modprobe.d/$mod-blacklist.conf" ] ; then
        BL=$(grep -P "^blacklist $mod" /etc/modprobe.d/$mod-blacklist.conf)
        if [ "$?" = "0" ] ; then
            local NAME=$(echo "$mod" | tr '[:lower:]' '[:upper:]')
            local VAR="${NAME}_MOD_UNLOCK"
            question "      - The $NAME module is blacklisted, do you want to unlock it ?" "Yn" "$VAR"
        fi
    fi
}

function module_unlock
{
    local mod="$1"

    if [ -e "/etc/modprobe.d/$mod-blacklist.conf" ] ; then
        local NAME=$(echo "$mod" | tr '[:lower:]' '[:upper:]')
        local VAR="${NAME}_MOD_UNLOCK"
        if [ "${!VAR}" = "y" ] ; then
            perl -p -i -e "s/^blacklist $mod/#blacklist $mod/" "/etc/modprobe.d/$mod-blacklist.conf"
        fi
    fi
}

function install_sctp
{
    case $LINUX_DISTRIB in
    fedora|rhel)
        install_package kernel-modules-extra lksctp-tools
        # Remove old crontab (from old OTS scripts)
        if [ -e "/root/start.sh" ] ; then
            crontab -r
            rm -f /root/start.sh
        fi
        module_unlock "sctp"
        ;;
    ubuntu|centos|raspbian)
        install_package lksctp-tools
        ;;
    esac
}

function autostart_comp
{
    local ID="$1"
    local DEF

    local OLD="${ID}_AUTOSTART_OLD"
    case "${!OLD}" in
    n)
        DEF="yN"
        ;;
    y)
        DEF="Yn"
        ;;
    *)
        DEF="${ID}_AUTOSTART_DEFAULT"
        DEF=${!DEF}
        if [ "$DEF" = "" ] ; then
            DEF="$2"
        fi
        ;;
    esac
    if [ "$DEF" != "" ] ; then
        question "      - Do you want to start automatically ?" "$DEF" "${ID}_AUTOSTART"
    fi
}

# Update default answers
if [ "$UE_INSTALL" = "y" ] ; then
    if [ "$MME_INSTALL" = "" ] ; then SetDefault "MME" "yN"; fi
    if [ "$ENB_INSTALL" = ""  ] ; then SetDefault "ENB" "yN"; fi
    if [ "$MBMSGW_INSTALL" = "" ] ; then SetDefault "MBMSGW" "yN"; fi
fi

#######
# OTS #
#######
if [ "$LINUX_DISTRIB" = "rhel" ] ; then
    if [ "$(which screen 2>/dev/null)" = "" ] ; then
        echo -e "\033[93m  Warning, OTS package not available on Red Hat because of screen program not available,"
        echo -e         "  you may install it manually.\033[0m"
        question "  Continue ?" "Yn" "CONT"
        if [ "$CONT" = "n" ] ; then
            exit 0
        fi
        OTS_ARCH=""
    fi
fi

configure_comp "OTS" "ots" "LTE automatic service" "package:screen"
if [ "$OTS" != "" ] ; then
    if [ "$LINUX_SERVICE" != "" ] ; then
        SetDefault "SRV" "Yn"
        question "      - Do you want to enable ${OTS_NAME} ?" "$SRV_DEFAULT" "SRV_INSTALL"
    fi

    # Global config params
    for c in $COMP_LIST ; do
        case "$c" in
        mme)
            CONF_NAT="y"
            CONF_IPV6="y"
            CONF_NAT6="y"
            ;;
        mbmsgw)
            CONF_IPV6="y"
            ;;
        enb|view|probe|scan|ue)
            CONF_HT="y"
            ;;
        esac
    done
    if [ "$CONF_NAT" = "y" ] ; then
        SetDefault "NAT" "Yn"
        question "      - Do you want to use NAT for IPv4 ?" "$NAT_DEFAULT" "NAT_INSTALL"
    fi
    if [ "$CONF_IPV6" = "y" ] ; then
        SetDefault "IPV6" "Yn"
        question "      - Do you want to use IPv6 ?" "$IPV6_DEFAULT" "IPV6_INSTALL"
        if [ "$IPV6_INSTALL" = "y" -a "$CONF_NAT6" ] ; then
            SetDefault "IPV6_NAT" "Yn"
            question "      - Do you want to use NAT for IPv6 ?" "$IPV6_NAT_DEFAULT" "IPV6_NAT_INSTALL"
        fi
    fi

    # Hyperthreading
    if [ "$CONF_HT" = "y" ] ; then
        GetHTState
        if [ "$HT_SYS_STATE" = "on" -o "$HT_SYS_STATE" = "off" ] ; then
            DEF="Yn"
            if [ "$HT_STATE" = "on" ] ; then
                DEF="yN"
            fi
            if [ "$HT_INSTALL" = "y" ] ; then
                NO_HT="n"
            elif [ "$HT_INSTALL" = "n" ] ; then
                NO_HT="y"
            fi
            question "      - Do you want to turn hyperthreading off (we strongly recommand it) ?" "$DEF" "NO_HT"
            if [ "$NO_HT" = "y" ] ; then
                HT_STATE="off"
            else
                HT_STATE="on"
            fi
        fi
    fi

    # Get current config vars
    if [ -e "$OTS_OLD_PATH/config/ots.cfg" ] ; then
        OTS_OLD_CONFIG=$({
            cd $OTS_OLD_PATH/config
            source ots.cfg
            CONFIG_FILE="../.lte.config"
            if [ -e "$CONFIG_FILE" ] ; then
                source $CONFIG_FILE
            fi
            echo "HT_STATE=$HT_STATE"
            for c in $COMP_LIST ; do
                C=$(echo "${c}" | tr '[:lower:]' '[:upper:]')
                VAR="${C}_AUTOSTART"
                if [ "${!VAR}" != "" ] ; then
                    echo "${VAR}_OLD=\"${!VAR}\""
                fi
            done
            if [ "$OTS_ADDRESS" != "" ] ; then
                echo "OTS_ADDRESS=$OTS_ADDRESS"
            fi
        })
        eval "$OTS_OLD_CONFIG"
    fi

fi

#######
# EPC #
#######
configure_comp "MME" "mme" "EPC" "package:lksctp-tools"
module_check "sctp" "$MME"

if [ "$MME" != "" ] ; then
    if [ "$(tar tzf ${MME_ARCH} | grep lteims)" != "" ] ; then
        SetDefault "IMS" "Yn"
        IMS_DIR="${IDIR}/mme"
        question "      - Do you want to install IMS ?" "$IMS_DEFAULT" "IMS_INSTALL"
    fi
fi


#######
# eNB #
#######
configure_comp "ENB" "enb" "eNB" "package:lksctp-tools"
configure_comp_trx "ENB"
module_check "sctp" "$ENB"

# MIMO use
if [ "$MIMO_INSTALL" = "" -a "$ENB" != "" ] ; then
    CFG="$IDIR/enb/config/enb.cfg"
    DEF="Yn"
    if [ -e "$CFG" ] ; then
        if [ "$(grep m_ri $CFG)" = "" ] ; then
            DEF="yN"
        fi
    fi
    question "      - Do you want to use MIMO ?" "$DEF" "MIMO_INSTALL"
fi

#########
# N3IWF #
#########
SetDefault "N3IWF" "yN"
configure_comp "N3IWF" "n3iwf" "N3IWF" "package:lksctp-tools"
module_check "sctp" "$N3IWF"

######
# UE #
######
if [ "$ENB" != "" -o "$MME" != "" ] ; then
    SetDefault "UE" "yN"
    SetDefault "UE_AUTOSTART" "yN"
fi
configure_comp "UE" "ue" "UE simulator"
configure_comp_trx "UE"

if [ "$UE" != "" -a "$OTS" != "" ] ; then
    autostart_comp "UE" "Yn"
fi

########
# View #
########
SetDefault "VIEW" "yN"
configure_comp "VIEW" "view" "Spectrum viewer"
configure_comp_trx "VIEW"

if [ "$VIEW" != "" -a "$OTS" != "" ] ; then
    SetDefault "VIEW_AUTOSTART" "yN"
    autostart_comp "VIEW" "yN"
fi

#########
# Probe #
#########
if [ "$ENB" != "" -o "$UE" != "" ] ; then
    SetDefault "PROBE" "yN"
fi
configure_comp "PROBE" "probe" "LTE probe"
configure_comp_trx "PROBE"

if [ "$PROBE" != "" -a "$OTS" != "" ] ; then
    autostart_comp "PROBE" "yN"
fi


########
# Scan #
########
SetDefault "SCAN" "yN"
configure_comp "SCAN" "scan" "LTE scanner"
configure_comp_trx "SCAN"

if [ "$SCAN" != "" -a "$OTS" != "" ] ; then
    autostart_comp "SCAN" "yN"
fi


#######
# SAT #
#######
SetDefault "SAT" "yN"
configure_comp "SAT" "sat" "Satellite utilities"

if [ "$SAT" != "" -a "$OTS" != "" ] ; then
    autostart_comp "SAT" "Yn"
fi


##########
# MBMSGW #
##########
configure_comp "MBMSGW" "mbms" "MBMS gateway" "package:lksctp-tools"
module_check "sctp" "$MBMSGW"


#######
# WWW #
#######
configure_comp "WWW" "" "Web interface" "package:apache php" "and enable your web server."


SetDefault "LICENSE" "yN"
configure_comp "LICENSE" "license" "license server"

SetDefault "MONITOR" "yN"
configure_comp "MONITOR" "monitor" "LTE monitoring" "package:nodejs ssmtp"


############
# Licenses #
############
if [ -d "licenses" ] ; then
    # Get all license_uid
    declare -A LUIDS
    declare -A LICENSE_COPY
    declare -A DONGLE_PATH
    LICENSE_DUP=()
    LICENSE_PATH="${USERDIR}/.amarisoft/"
    CUSTOMER_KEY="c7b2ee871d7d4772647de1c24211991b"
    PAT_LUID="license_uid=\K[\d_]+"
    PAT_ID="([\da-f]{2}-){7}[\da-f]{2}"

    # Analyze current licenses: find all license_uid and identify duplicates
    LICENSE_LIST=""
    if [ -d "$LICENSE_PATH" ] ; then
        LICENSE_LIST=$(find ${LICENSE_PATH} -type f)
    fi
    for name in $(ls /dev/disk/by-id | grep "usb" | grep "\-part") ; do
        DEV=$(readlink -f "/dev/disk/by-id/$name")
        MP=$(cat /proc/mounts | grep -s "$DEV" | awk '{print $2;}' || echo '')
        DPATH="$MP/.amarisoft"
        if [ "$MP" != "" -a -d "$DPATH" ] ; then
            LICENSE_LIST+=" $(find $DPATH/ -type f)"
            if [ -e "$DPATH/.dongle-id" ] ; then
                DONGLEID=$(cat "$DPATH/.dongle-id")
                DONGLE_PATH[$DONGLEID]="$DPATH"
            fi
        fi
    done
    for f in $LICENSE_LIST ; do
        LUID=$(cat $f | tail -c +261 | grep -oP "$PAT_LUID")
        if [ "$LUID" != "" ] ; then
            if [ "${LUIDS[$LUID]}" = "" ] ; then
                LUIDS[$LUID]="$f"
            else
                LICENSE_DUP+=($f)
            fi
        fi
    done

    # Check from tarball licenses to copy (same license_uid)
    for f in $(find licenses/ -type f) ; do
        IDS=$(cat $f | openssl aes-128-cbc -a -d -pbkdf2 -salt -k "$CUSTOMER_KEY" 2>/dev/null | tail -c +261 | grep -oP "\w+id=[\da-f_-]+")
        if [ "$IDS" = "" ] ; then continue; fi

        LUID=$(echo "$IDS" | grep -oP "$PAT_LUID")
        if [ "$LUID" = "" ] ; then continue; fi # License from server must have a license uid

        # Known, update it
        if [ "${LUIDS[$LUID]}" != "" ] ; then
            LICENSE_COPY[$f]="${LUIDS[$LUID]}"
            continue
        fi

        if [ "$PROD_HOSTID" != "" ] ; then
            HOSTID=$(echo "$IDS" | grep -oP "host_id=\K$PAT_ID")
            if [ "$HOSTID" = "$PROD_HOSTID" ] ; then
                LICENSE_COPY[$f]="${LICENSE_PATH}/$(basename $f)"
                continue;
            fi
        fi
        DONGLEID=$(echo "$IDS" | grep -oP "dongle_id=\K$PAT_ID")
        if [ "$DONGLEID" != "" ] ; then
            if [ "${DONGLE_PATH[$DONGLEID]}" != "" ] ; then
                LICENSE_COPY[$f]="${DONGLE_PATH[$DONGLEID]}/$(basename $f)"
            fi
        fi
    done

    # Filter same files
    for f in ${!LICENSE_COPY[@]} ; do
        cat "$f" | openssl aes-128-cbc -a -d -pbkdf2 -salt -k "$CUSTOMER_KEY" | diff "${LICENSE_COPY[$f]}" - > /dev/null
        if [ "$?" = "0" ] ; then
            unset LICENSE_COPY[$f]
        fi
    done

    if [ "${#LICENSE_COPY[@]}" != "0" ] ; then
        SetDefault "LICENSE_UPDATE" "Yn"
        question "  * Do you want to update your license files ? (${#LICENSE_COPY[@]} found)" "$LICENSE_UPDATE_DEFAULT" "LICENSE_UPDATE_INSTALL"
    fi
fi


#########
# Clean #
#########
INSTALLED_VERSIONS=()

# Associate files to versions
UpdateWWW
declare -A INSTALLED_FILES
for d in ${IDIR} ${WWW_PATH} ; do
    if [ ! -d "$d" ] ; then continue; fi
    INSTALLED_FILES1=$(ls ${d} | grep -P '(^lte|^trx|^amarisoft).*\d{4}-\d{2}-\d{2}')
    for i in $INSTALLED_FILES1 ; do
        V=$(echo $i | grep -o -P "\d{4}-\d{2}-\d{2}")
        if [ "$V" != "" ] ; then
            if [ "${INSTALLED_FILES[$V]}" = "" ] ; then
                INSTALLED_VERSIONS+=( $V )
            fi
            INSTALLED_FILES[$V]+=" $d/$i"
        fi
    done
done

# Sort and remove last lines
CLEAN_VERSION_LIST=$(echo "${INSTALLED_VERSIONS[@]}" | xargs -n 1 | sort | head -n -$CLEAN_KEEP_COUNT | xargs -r echo)
if [ "$CLEAN_VERSION_LIST" != "" ] ; then
    CVL=$(echo "$CLEAN_VERSION_LIST" | sed -e 's/ /, /g')
    question "  * Do you want to remove following old versions:\n    $CVL ?" "Yn" "CLEAN"
fi


if [ "$DRY_RUN" = "y" ] ; then
    exit 0
fi

# End of configuration


function install_dir
{
    # $1 => install path
    # $2 => dir
    # $3 => name
    # $4 => old (opt)
    local DIR="${1}/${2}"
    if [ -d "${DIR}" ] ; then
        if [ "$4" != "" ] ; then
            local OLD="${!4}"
            if [ "$OLD" = "${DIR}" ] ; then
                eval "$4=$OLD.bak"
            fi
        fi
        rm -Rf "${DIR}.bak"
        mv "${DIR}" "${DIR}.bak"
    elif [ -e "" ] ; then
        rm -f "${DIR}"
    fi
    mv "${2}" "${1}/"

    rm -Rf "${1}/${3}"
    ln -s "${1}/${2}" "${1}/${3}"
    touch "${1}/${2}" # Set modification date to install date
    chown $USER:$USER "${1}/${3}"
}

function MigrateConfig
{
    local ID="$1"
    local LINKS="$2"

    local DIR="${ID}_DIR"
    DIR="${IDIR}/${!DIR}"

    # Config
    CFG1="$DIR/config"
    # Create md5 file
    touch "$CFG1/.md5"
    for i in $(cd $CFG1 && find -type f -name '*' -not -path '*/\.*' | sed -e "s'./''") ; do
        MD5=$(cd $CFG1 && md5sum $i | cut -d ' ' -f1)
        echo "$i:$MD5" >> "$CFG1/.md5"
    done

    # Retrieve config ?
    local OLD="${ID}_OLD_PATH"
    OLD="${!OLD}"
    CFG0="$OLD/config"
    if [ -d "$CFG0" ] ; then
        # Previous md5 file exists ?
        local MD5="$CFG0/.md5"
        if [ ! -e "$MD5" ] ; then
            MD5=""
        fi

        echo "  Migrate configuration files"

        # Get old config files
        local COUNT="0"
        for i in $(cd $CFG0 && find \( -type f -o -type l \) -name '*' -not -path '*/\.*' | sed -e "s'./''") ; do

            local SRC="$CFG0/$i"
            local DST="$CFG1/$i"

            # Get entry in reference md5 file
            if [ "$MD5" != "" ] ; then
                REF=$(grep -P "^$i:" $MD5)
            else
                REF=""
            fi

            # Is file a reference one ?
            if [ "$REF" != "" ] ; then

                # Check if reference still exists
                if [ -e "$DST" ] ; then
                    MD5_0=$(echo "$REF" | cut -d ':' -f2)
                    MD5_1=$(md5sum $SRC | cut -d ' ' -f1)
                    if [ "$MD5_0" != "$MD5_1" ] ; then
                        echo -e "    \033[93mWarning, reference config file $i was modified\033[0m"
                        echo -e "    \033[93m  It has been imported as $i.bak, you may report your changes manually\033[0m"
                        cp -ap "$SRC" "$DST.bak"
                    fi
                else
                    # Legacy hack
                    case "$i" in
                    sib23.asn|sib23_br.asn|sib23_br_ce.asn|sib23_nosrs.asn)
                        i1=$(echo "$i" | sed -e "s/23/2_3/")
                        echo -e "    \033[93mWarning, $i is deprecated, use $i1 instead\033[0m"
                        (cd $CFG1 && ln -s $i1 $i)
                        ;;
                    esac
                fi
            else
                if [ -e "$DST" ] ; then
                    # Check if DST is default link
                    for LINK in $(echo $LINKS) ; do
                        if [ "$DST" = "$CFG1/$LINK" ] ; then
                            # Hugly hack for bad name transition
                            if [ "$(readlink $SRC)" != "ims-default.cfg" -a "$(readlink $SRC)" != "mme-default.cfg" ] ; then
                                if [ -L "$SRC" ] ; then
                                    rm -f "$DST"
                                    cp -ap "$SRC" "$DST"
                                else
                                    echo -e "    \033[93mWarning, your current config file $i is not a symbolic link\033[0m"
                                    echo -e "    \033[93m  It has been imported as $i.bak, you may report your changes manually\033[0m"
                                    cp -ap "$SRC" "$DST.bak"
                                fi
                            fi
                            DST=""
                            break
                        fi
                    done

                    if [ -L "$SRC" -a -L "$DST" ] ; then
                        # XXX: check value of symlinks but beware of rf_driver link
                        DST=""
                    fi

                    if [ "$DST" != "" -a "$MD5" != "" ] ; then
                        echo -e "    \033[93mWarning, $i config file conflicts with new release\033[0m"
                        echo -e "    \033[93m  It won't be imported, you may report your changes manually\033[0m"
                    fi
                else
                    mkdir -p $(dirname "$DST")
                    cp -ap "$SRC" "$DST"
                    COUNT=$(( $COUNT + 1 ))
                fi
            fi
        done
        if [[ $COUNT -gt 0 ]] ; then
            echo "    $COUNT config file(s) imported"
        else
            echo "    No config file(s) imported"
        fi

        # Copy old history file
        for i in $(find ${OLD}/ -maxdepth 1 -name "*history"); do
            cp -p "$i" "${DIR}/"
        done

        # Copy saved files
        local SAVE="${OLD}/$SAVE_DIR"
        if [ -d "$SAVE" ] ; then
            cp -rp "$SAVE/" "${DIR}/"
        fi
    fi
}

function AddOTSConfig
{
    if [ "$OTS" != "" ] ; then

        if [ "$OTS_CFG" = "" ] ; then
            OTS_CFG="${IDIR}/${OTS_LINK}/config/ots.cfg"
            echo "# Start of section generated by installer" >> "$OTS_CFG"
            echo "# $(date -u)" >> "$OTS_CFG"
        fi

        while [[ ${1+x} ]] ; do
            echo "$1" >> "$OTS_CFG"
            shift
        done
    fi
}

function libs_install
{
    local ID="$1"
    local LINK="${ID}_LINK"
    LINK="${!LINK}"
    local DST="${IDIR}/$LINK"
    shift

    for lib in $@ ; do
        case "$lib" in
        openssl)
            list=$(find libs/${TARGET}/ -name "libcrypto.so*" -o -name "libssl.so*")
            ;;
        nghttp2)
            list=$(find libs/${TARGET}/ -name "libnghttp2.so*")
            ;;
        *)
            echo "Unknown lib $lib for $ID"
            exit 1
        esac
        for i in $list ; do
            cp $i $DST/
        done
    done
}

function SetMainDefaultLink
{
    SetDefaultLink "$1" "$2"

    AddOTSConfig "${1}_CONFIG_FILE=\"config/${2}.cfg\""
}

function SetDefaultLink
{
    local LINK="${1}_LINK"
    local CFG="${2}"
    LINK="${!LINK}"

    (cd ${IDIR}/$LINK/config && mv ${CFG}.cfg ${CFG}.default.cfg && ln -s ${CFG}.default.cfg ${CFG}.cfg)
}

function cmd
{
    tag="$1"
    shift
    set -o pipefail
    stdbuf -oL -eL $@ 2>&1 | stdbuf -oL -eL sed "s/^/    [$tag] /" | sed "s/\r/\r    [$tag] /g"
    CMD="$?"
    set +o pipefail
}

##########################
# Start of installations #
##########################

if [ ! -d "$IDIR" ] ; then
    mkdir -p $IDIR
    chown $USER:$USER $IDIR
fi

# Reset
rm -f "$LAST_INSTALL_FILE"
touch "$LAST_INSTALL_FILE"
echo "LAST_IDIR=\"$IDIR\" # Last install dir" >> $LAST_INSTALL_FILE

step=$(($step+1))



# OTS
install_comp "OTS"
if [ "$OTS" != "" ] ; then

    install_package screen

    # Legacy purge
    rm -f /usr/local/bin/ltelogs.sh /usr/local/bin/ltestart.sh
    case $LINUX_DISTRIB in
    fedora)
        # Remove old crontab (from old OTS scripts)
        if [ -e "/root/start.sh" ] ; then
            crontab -r
            rm -f /root/start.sh
        fi
        ;;
    esac

    # Service
    service_cmd lte "stop"
    service_install "lte" "${IDIR}/${OTS_LINK}" "$USER" "$SRV_INSTALL"
    StoreDefault "SRV" "$SRV_INSTALL"

    # Screen config (Legacy)
    if [ -e "${USERDIR}/.screenrc" ] ; then
        perl -p -i -e "s/source .screenrc.amarisoft//" "${USERDIR}/.screenrc"
    fi
    rm -f "${USERDIR}/.screenrc.amarisoft"
fi

# Web portal
if [ -e "${WWW}.tar.gz" ] ; then
    echo "$step) Install ${WWW_NAME}"
    case $LINUX_DISTRIB in
    fedora|centos)
        install_package php httpd

        if [[ "$LINUX_VERSION" -gt 27 ]] ; then
            install_package php-json
        fi

        HTTPD="httpd"
        ;;
    rhel)
        install_package php httpd php-json
        HTTPD="httpd"
        ;;
    ubuntu|raspbian)
        install_package apache2
        if [ "$LINUX_VERSION" -lt "15" ] ; then
            install_package php5
        else
            install_package php libapache2-mod-php
        fi
        HTTPD="apache2"
        ;;
    debian)
        install_package apache2 php libapache2-mod-php
        HTTPD="apache2"
        ;;
    esac

    case $LINUX_SERVICE in
    systemd)
        # Allow HTTPD to access common /tmp
        PLIST="${HTTPD} php-fpm"
        for i in $PLIST ; do
            file="/lib/systemd/system/${i}.service"
            if [ -e "$file" ] ; then
                rm -f $file.patch
                cat $file | sed -e "s/^PrivateTmp/#PrivateTmp/" > $file.patch
                if [ -s "$file.patch" ] ; then
                    cp $file $file.bak
                    cp $file.patch $file
                fi
                rm -f $file.patch
                if [ ! -s "$file" ] ; then
                    echo -e "\033[93mWarning, empty $i service file, you may reinstall package.\033[0m"
                fi
            fi
        done
        systemctl -q --system daemon-reload
        systemctl -q enable $HTTPD
        systemctl -q restart $HTTPD
        ;;
    esac

    UpdateWWW
    if [ -d "$WWW_PATH" ] ; then
        WWW_OLD_PATH=$(readlink -f ${WWW_PATH}/lte)

        # Update
        untar ${WWW}.tar.gz
        install_dir "${WWW_PATH}" "${WWW}" "lte" "WWW_OLD_PATH"

        if [ -e "libs/node_modules.tgz" ] ; then
            untar "libs/node_modules.tgz"
            mv node_modules "${WWW_PATH}/${WWW}/"
        fi

        # Keep .htaccess
        if [ -e "${WWW_OLD_PATH}/.htaccess" ] ; then
            echo "  Import .htaccess"
            cp -p ${WWW_OLD_PATH}/.htaccess ${WWW_PATH}/lte/
        fi

        if [ "$OTS" != "" ] ; then
            LTE_TOOLBOX_FILES="lte_toolbox libnuma.so"
            if [ -e "${IDIR}/${OTS_DIR}/libc_wrapper.so" ] ; then
                LTE_TOOLBOX_FILES+=" libc_wrapper.so"
            fi
            for f in $LTE_TOOLBOX_FILES ; do
                cp ${IDIR}/${OTS_DIR}/$f ${WWW_PATH}/lte/
            done
        fi

        # Redirect
        if [ ! -e "${WWW_PATH}/index.html" ] ; then
            echo "<script>location.href='lte/';</script>" > "${WWW_PATH}/index.html"
        fi

        # SELinux (Do it silently)
        if [ "$(which chcon 2>/dev/null)" != "" ] ; then
            chcon -R --reference=${WWW_PATH} ${WWW_PATH}/lte/ 2>/dev/null
            if [ "$OTS" != "" ] ; then
                (cd ${WWW_PATH}/lte/ && chcon -t httpd_exec_t $LTE_TOOLBOX_FILES -R 2>/dev/null)
            fi
        fi

        OTS_ADDRESS_CFG="OTS_ADDRESS=\"${OTS_ADDRESS}\" # Set it to force WS address of components from GUI"
        if [ "$OTS_ADDRESS" = "" ] ; then
            OTS_ADDRESS_CFG="#$OTS_ADDRESS_CFG"
        fi
        AddOTSConfig "$OTS_ADDRESS_CFG"
        AddOTSConfig "WWW_PATH=\"${WWW_PATH}/lte/\""
    else
        echo -e "\033[93mWarning, can't find www path !\033[0m"
    fi

    step=$(($step+1))
fi

# TRX
for i in $TRX_LIST ; do
    VAR="TRX_${i}_INSTALL"
    if [ "${!VAR}" = "y" ] ; then

        echo "$step) Install TRX ${i}"

        TRX_DIR="TRX_${i}_DIR"
        rm -Rf ${!TRX_DIR}
        untar ${!TRX_DIR}.tar.gz
        TRX_LINK="trx_${i}"
        install_dir "${IDIR}" "${!TRX_DIR}" "${TRX_LINK}"

        step=$(($step+1))
    fi
done

# MME
install_comp "MME" "0"
if [ "$MME" != "" ] ; then

    case $LINUX_DISTRIB in
    ubuntu)
        if [ "$LINUX_VERSION" -gt 19 ] ; then
            install_package net-tools
        fi
        ;;
    esac
    install_sctp
    libs_install "MME" "openssl" "nghttp2"

    MME_INIT=''
    if [ "$NAT_INSTALL" = "n" ] ; then
        MME_INIT+=' --no-nat'
    fi
    if [ "$IPV6_INSTALL" = "y" ] ; then
        MME_INIT+=' -6'
        if [ "$IPV6_NAT_INSTALL" = "n" ] ; then
            MME_INIT+=' --no-nat6'
        fi
    fi

    StoreDefault "IMS" "$IMS_INSTALL"
    StoreDefault "NAT" "$NAT_INSTALL"
    StoreDefault "IPV6" "$IPV6_INSTALL"
    StoreDefault "IPV6_NAT" "$IPV6_NAT_INSTALL"

    AddOTSConfig "MME_INIT=\"$MME_INIT\""

    SetMainDefaultLink "MME" "mme"

    # IMS
    if [ "${IMS_DIR}" != "" -a "$IMS_INSTALL" = "y" ] ; then
        echo "  Configure IMS"

        IMS_NAME="IMS"
        IMS_LINK="$MME_LINK"
        add_ots_comp "IMS" "3"
        AddOTSConfig "IMS_DEP=\"MME\""

        (cd ${IMS_DIR}/config && rm -f mme.cfg && ln -s mme-ims.cfg mme.cfg)
        SetMainDefaultLink "IMS" "ims"

        # Do it after IMS
        MigrateConfig "MME" "mme.cfg ims.cfg"
    else
        MigrateConfig "MME" "mme.cfg"
    fi
fi

# eNB
install_comp "ENB" "1"
if [ "$ENB" != "" ] ; then
    install_sctp
    libs_install "ENB" "openssl"

    if [ "$MIMO_INSTALL" = "y" ] ; then
        (cd ${IDIR}/enb/config && perl -p -i -e 's/(N_ANTENNA_.L +)\d/${1}2/' enb.cfg)
    fi

    AddOTSConfig "ENB_INIT=\"\""
    AddOTSConfig "ENB_RRH_CHECK=\"config/rf_driver/rrh_check.sh\""

    SetMainDefaultLink "ENB" "enb"
    MigrateConfig "ENB" "enb.cfg"
fi

# UE
install_comp "UE" "2"
if [ "${UE}" != "" ] ; then
    libs_install "UE" "openssl"

    AddOTSConfig "UE_INIT=\"\""
    AddOTSConfig "UE_RRH_CHECK=\"config/rf_driver/rrh_check.sh\""
    AddOTSConfig "UE_SCRIPT=\"config/ots-script.sh\""

    SetMainDefaultLink "UE" "ue"
    MigrateConfig "UE" "ue.cfg"
fi

# MBMSGW
install_comp "MBMSGW" "4"
if [ "${MBMSGW}" != "" ] ; then
    install_sctp
    libs_install "MBMSGW" "openssl"
    AddOTSConfig "MBMSGW_CONFIG_FILE=\"config/mbmsgw.cfg\""

    if [ "$IPV6_INSTALL" = "y" ] ; then
        AddOTSConfig "MBMSGW_INIT=\"-6\""
    else
        AddOTSConfig "MBMSGW_INIT=\"\""
    fi
fi

# N3IWF
install_comp "N3IWF" "5"
if [ "${N3IWF}" != "" ] ; then
    install_sctp
    libs_install "N3IWF" "openssl"

    AddOTSConfig "N3IWF_INIT=\"\""

    SetMainDefaultLink "N3IWF" "n3iwf"
    MigrateConfig "N3IWF" "n3iwf.cfg"
fi

# License server
install_comp "LICENSE" "6"
if [ "${LICENSE}" != "" ] ; then
    libs_install "LICENSE" "openssl"
    SetMainDefaultLink "LICENSE" "license"
    MigrateConfig "LICENSE" "license.cfg"
fi

# Probe
install_comp "PROBE" "7"
if [ "${PROBE}" != "" ] ; then
    libs_install "PROBE" "openssl"

    AddOTSConfig "PROBE_INIT=\"\""
    SetMainDefaultLink "PROBE" "probe"
    MigrateConfig "PROBE" "probe.cfg"
fi

# View
install_comp "VIEW" "8"
if [ "$VIEW" != "" ] ; then
    libs_install "VIEW" "openssl"

    SetDefaultLink "VIEW" "view"
    MigrateConfig "VIEW" "view.cfg"
fi

# Scan
install_comp "SCAN" "9"
if [ "${SCAN}" != "" ] ; then
    libs_install "SCAN" "openssl"

    AddOTSConfig "SCAN_INIT=\"\""
    SetMainDefaultLink "SCAN" "scan"
    MigrateConfig "SCAN" "scan.cfg"
fi

# Sat
install_comp "SAT" "10"
if [ "${SAT}" != "" ] ; then
    libs_install "SAT" "openssl"

    AddOTSConfig "SAT_ARGS=\"-m\""
    SetMainDefaultLink "SAT" "sat-mc"
    MigrateConfig "SAT" "sat-mc.cfg"
fi


# Monitoring system
install_comp "MONITOR"
if [ "$MONITOR" != "" ] ; then
    case $LINUX_DISTRIB in
    fedora|ubuntu|centos|raspbian|debian)
        install_package nodejs ssmtp
        ;;
    rhel)
        install_package nodejs
        ;;
    esac

    SetMainDefaultLink "MONITOR" "monitor"
    MigrateConfig "MONITOR" "monitor.cfg"
    mkdir -p "$IDIR/$MONITOR/$SAVE_DIR"
fi

# License files
if [ "$LICENSE_UPDATE_INSTALL" = "y" ] ; then
    echo "$step) Update licenses"

    echo "  Update ${#LICENSE_COPY[@]} license(s)"
    for f in ${!LICENSE_COPY[@]} ; do
        rm -f "${LICENSE_COPY[$f]}"
        cat "$f" | openssl aes-128-cbc -a -d -pbkdf2 -salt -k "$CUSTOMER_KEY" > "${LICENSE_COPY[$f]}"
    done
    if [ "${#LICENSE_DUP[@]}" != "0" ] ; then
        echo "  Clean ${#LICENSE_DUP[@]} duplicated license(s)"
        for f in ${LICENSE_DUP[@]}; do
            rm -f "$f"
        done
    fi

    step=$(($step+1))
fi
StoreDefault "LICENSE_UPDATE" "$LICENSE_UPDATE_INSTALL"

# End of OTS
if [ "$OTS" != "" ] ; then
    echo "$step) Finalize $OTS_NAME"

    SetDefaultLink "OTS" "ots"
    MigrateConfig "OTS" "ots.cfg"

    AddOTSConfig "" "# System configuration"
    if [ "$HT_STATE" != "" ] ; then
        AddOTSConfig "HT_STATE=\"${HT_STATE}\""
    fi

    AddOTSConfig "" "# End of section generated by installer" ""

    # Legacy
    H=$(eval echo ~$USER)
    _LTE="$H/.lte"
    if [ -e "$_LTE" ] ; then
        FILE="ots.legacy.cfg"
        CFG="$IDIR/$OTS/config/$FILE"

        echo "  Migrate $_LTE to $FILE"

        echo "# Configuration file generated by installer version 2025-06-13" > "$CFG"
        echo "source ots.default.cfg" >> "$CFG"
        echo "" >> "$CFG"
        echo "# Configuration of legacy $_LTE file" >> "$CFG"
        cat "$_LTE" >> "$CFG"

        # Update symlink
        (cd $IDIR/$OTS/config/ && rm -f ots.cfg && ln -s $FILE ots.cfg)

        rm -f "$_LTE"
    fi

    case "$PROD_MODEL" in
    UESB|UESBE|UESBNG|UESBMBS|CBU|CBP|CBA|CBX|CBE|CBM)
        PROG=$(which tuned-adm 2>/dev/null || true);
        if [ "$PROG" != "" ] ; then
            mkdir -p /usr/lib/tuned/amarisoft
            CFG0="/usr/lib/tuned/amarisoft/tuned.conf"
            CFG1="${IDIR}/${OTS_LINK}/amarisoft-tuned.profile"
            if [ -e "$CFG0" ] ; then
                CMDLINE0=$(cat $CFG0 | grep cmdline)
                CMDLINE1=$(cat $CFG1 | grep cmdline)
                if [ "$CMDLINE0" != "$CMDLINE1" ] ; then
                    echo "  Please reboot your system to update whole system configuration"
                fi
            fi

            cp $CFG1 $CFG0
            tuned-adm profile amarisoft
        fi
        ;;
    esac

    case "$PROD_MODEL" in
    UESB|UESBE|UESBNG|UESBMBS|CBU|CBP|CBA|CBX|CBE|CBC|CBM)
        if [ "$LINUX_SERVICE" = "systemd" ] ; then
            while read -r line ; do
                S=$(echo "$line" | awk '{print $1;}' | sed -e "s/\.service//")
                case "$S" in
                alsa-state|avahi-daemon|abrt-xorg|cups|bluetooth|libvirtd|ModemManager|earlyoom)
                    echo "  Disable/stop service $S"
                    systemctl disable $S
                    systemctl stop $S
                    ;;
                esac
            done < <(systemctl --type=service)
        fi
        ;;
    esac

    if [ "$LOG_FILE" != "" ] ; then
        LTE_LOG="/tmp/lte.log"
        echo "$(date '+%Y-%m-%d %H:%M:%S') [OTS] - OTS: Install $VERSION" >> $LTE_LOG
        cat $LOG_FILE | sed -e "s/^/        /" | sed -e "s/$(echo -e \\033)\[[[:digit:]]*m//g" >> $LTE_LOG
    fi

    if [ "$SRV_INSTALL" = "y" ] ; then
        echo "  Start service"
        service_cmd lte "start"
    fi

    step=$(($step+1))
fi

# Clean ?
if [ "$CLEAN" = "y" ] ; then
    echo "$step) Clean"

    # Remove old files
    for i in $CLEAN_VERSION_LIST ; do
        echo "  Remove version $i"
        rm -Rf ${INSTALLED_FILES[$i]}
    done
fi

echo ""
if [ $ERROR_COUNT -gt 0 ] ; then
    echoTitle "*" "$ERROR_COUNT error(s) during installation"
    exit 1
else
    echoTitle "*" "Installation successful"
    exit 0
fi

