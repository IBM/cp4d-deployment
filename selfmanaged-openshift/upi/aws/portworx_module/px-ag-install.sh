#!/bin/sh
#
# Portworx air-gapped images helper v2.6.2.1
# - script copies Portworx container images to air-gapped hosts that do not have direct access to Internet
# - generated from https://install.portworx.com/air-gapped?kbver=1.18.3 on 2021-01-08T21:06:00Z
#

set -eu
if [ -n "${BASH+set}" ]; then
    set -o pipefail
    export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
fi

IMAGES=""
IMAGES="$IMAGES docker.io/portworx/px-enterprise:2.6.2.1"
IMAGES="$IMAGES docker.io/portworx/oci-monitor:2.6.2.1"
IMAGES="$IMAGES docker.io/openstorage/stork:2.6.0"
IMAGES="$IMAGES docker.io/portworx/autopilot:1.3.0"
IMAGES="$IMAGES docker.io/portworx/px-node-wiper:2.5.0"
IMAGES="$IMAGES docker.io/portworx/px-lighthouse:2.0.7"
IMAGES="$IMAGES docker.io/portworx/lh-config-sync:2.0.7"
IMAGES="$IMAGES docker.io/portworx/lh-stork-connector:2.0.7"
IMAGES="$IMAGES docker.io/portworx/talisman:1.1.0"
IMAGES="$IMAGES docker.io/portworx/px-operator:1.4.4"
IMAGES="$IMAGES k8s.gcr.io/pause:3.1"
IMAGES="$IMAGES gcr.io/google_containers/kube-controller-manager-amd64:v1.18.3"
IMAGES="$IMAGES gcr.io/google_containers/kube-scheduler-amd64:v1.18.3"
IMAGES="$IMAGES quay.io/k8scsi/csi-node-driver-registrar:v1.1.0"
IMAGES="$IMAGES quay.io/openstorage/csi-provisioner:v1.6.0-1"
IMAGES="$IMAGES quay.io/openstorage/csi-attacher:v1.2.1-1"
IMAGES="$IMAGES quay.io/k8scsi/csi-resizer:v0.5.0"
IMAGES="$IMAGES quay.io/k8scsi/csi-snapshotter:v2.1.0"
IMAGES="$IMAGES quay.io/k8scsi/snapshot-controller:v2.1.0"

TARBALL=px-agtmp.tar
RSH=ssh
LOAD=auto
VERBOSE=0
K8S_CMD=kubectl
K8SSECRET=px-install-secret
DRYRUN=0

# Colors init via tput
Cg="$(tput bold 2>/dev/null && tput setaf 0 2>/dev/null || /bin/true)"					# Gray
Cb="$(tput bold 2>/dev/null && tput setaf 7 2>/dev/null && tput setab 4 2>/dev/null || /bin/true)"	# White on Blue
Cy="$(tput bold 2>/dev/null && tput setaf 3 2>/dev/null && tput setab 0 2>/dev/null || /bin/true)"	# Yellow on Black
Cr="$(tput bold 2>/dev/null && tput setaf 3 2>/dev/null && tput setab 1 2>/dev/null || /bin/true)"	# Yellow on Red
CR="$(tput sgr0 2>/dev/null || /bin/true)"								# RESET

#
# LOGGER FUNCTIONS
#

# debug - prints an DEBUG message (normally gray on black)
debug() {
    [ $VERBOSE -le 0 ] || echo "$(date +'%F %T') $Cg DEBUG: $@ $CR" >&2
}

# info - prints an INFO message (normally white on blue)
info() {
    echo "$(date +'%F %T') $Cb INFO: $@ $CR" >&2
}

# warn - prints an WARN message (normally yellow on black)
warn() {
    echo "$(date +'%F %T') $Cy WARN: $@ $CR" >&2
}

# fail - prints a FATAL message (yellow on red) and exits the script
fail() {
    args=${@:-error}
    echo "$(date +'%F %T') $Cr FATAL $args $CR" >&2
    trap - EXIT
    exit 2
}

#
# RUNTIME DETECTION
#

# docker or podman?
if CNT_CMD=$(command -v podman) && test -n "$CNT_CMD" && $CNT_CMD info > /dev/null 2>&1 ; then
    true
else
    CNT_CMD=docker
fi
info "Using '$CNT_CMD' to handle container images locally"

#
# FUNCTIONS
#

exit_trap() {
    rc=$?
    rm -f "$TARBALL" "${TARBALL}.tmp"
    if [ $rc -eq 0 ]; then
        debug ".DONE"
    else
        warn "$0 FAILED (rc=$rc)"
    fi
    exit $rc
}
trap exit_trap EXIT

# dummy_cmd - replacement for docker/podman/kubelet to display parameters / output
dummy_cmd() {
    if echo "$@" | grep -q -- '-$'; then
        echo "DRY-RUN: $@ << EOF" >&2
        cat >&2
        echo EOF >&2
    else
        echo "DRY-RUN: $@" 2>&1
    fi
}

# num_images returns a number of images
num_images() {
    echo $IMAGES | wc -w
}

# pull_images - pulls Portworx container images
pull_images() {
    info "Pulling $(num_images) images from default container registries ..."
    for img in $IMAGES; do
        $CNT_CMD pull $img
    done
}

# load_images_nodes - loads container images to remote hosts
load_images_nodes() {
    [ $# -ge 1 ] || fail "load: Must provide list of nodes"

    if [ "x$RSH" = xbosh ]; then
        info "Will load remote nodes via bosh"
        transfer() {
            $RSH scp $1 $2:$1
            $RSH ssh $2 -- $LOAD $1
            $RSH ssh $2 -- rm -f $1
            debug "Loaded $3 to $2 via '$RSH'"
        }
    elif [ "x$LOAD" = xauto ]; then
        info "Testing container runtime at $1 ..."
        case "$($RSH $1 systemctl is-active crio docker | xargs)" in
            active*)
                # OpenShift-3.11 podman workaround: remove residual localhost image (e.g. localhost/busybox:latest)
                transfer() {
                    cat $1 | $RSH $2 podman load $3
                    debug "Loaded $3 to $2"
                    toRm="localhost/$(echo $3 | cut -d/ -f2-) localhost/$3"
                    $RSH $2 podman rmi -f $toRm > /dev/null 2>&1 || /bin/true
                }
                ;;
            *active)
                transfer() {
                    cat $1 | $RSH $2 docker load
                    debug "Loaded $3 to $2"
                }
                ;;
            *) fail "Neither Docker nor CRI-O services active on $1"  ;;
        esac
    else
        info "Will load remote nodes via user-specified '$LOAD'"
        transfer() {
            cat $1 | $RSH $2 "$LOAD"
            debug "Loaded $3 to $2 via '$LOAD'"
        }
    fi

    for img in $IMAGES; do
        info "Saving $img locally ..."
        $CNT_CMD save $img > "${TARBALL}.tmp" && mv "${TARBALL}.tmp" "$TARBALL"

        info "Loading $img into $@ nodes ..."
        pids=""
        for h in $@; do
            transfer "$TARBALL" $h $img &
            pids="$pids $!"
            info "> transfer of $img to $h in background (pid $!)"
        done
        debug "Waiting for load $img ..."
        for p in $pids; do
            wait $p || fail "Loading of $img failed  (pid $p)"
        done
        rm "$TARBALL"
    done
    info "Finished loading $(num_images) images to $# nodes."
}

# push_images_registry - loads container images into given registry
push_images_registry() {
    [ $# -eq 1 ] || fail "push: Must provide registry server"
    reg=${1%%/}

    info "Pushing $(num_images) images into $reg container registry/repository..."
    if echo $reg | grep -q /; then
        trans() {
            echo "$reg/$(basename $1)"
        }
    else
        trans() {
            i2="${1##docker.io/}"
            echo "$reg/${i2##quay.io/}"
        }
    fi
    for img in $IMAGES; do
        tg=$(trans $img)
        $CNT_CMD tag $img $tg
        $CNT_CMD push $tg
        $CNT_CMD rmi $tg
        debug "Pushed $tg into $reg"
    done
    info "Finished pushing $(num_images) images into $reg"
}

# import_secrets imports current docker/podman configuration as k8s secret
import_secrets() {
    if echo $CNT_CMD | grep -qw podman; then
        f=/run/user/0/containers/auth.json
        [ -f $f ] || f=/run/containers/0/auth.json
    else
        f=$HOME/.docker/config.json
    fi
    [ -f $f ] || fail "Registry secrets file $f not available"

    B64CONTENT=$(base64 -w0 $f)

    $K8S_CMD apply -f - << EOF
apiVersion: v1
data:
   .dockerconfigjson: $B64CONTENT
kind: Secret
metadata:
   name: $K8SSECRET
   namespace: kube-system
type: kubernetes.io/dockerconfigjson
EOF
    info "Registry secrets kube-system/$K8SSECRET imported from $f"
}

# usage - displays usage
usage() {
    rc=${1:-0}
    ME=$(readlink -m $0)
    [ ! -f "$ME" ] && ME='curl -fsSL https://install.portworx.com/air-gapped | sh -s --'
    cat << _EOF >&2
Usage: $ME <options> <commands>

IMAGE-COMMANDS:
    pull                      pulls the Portworx container images locally
    push <registry[/repo]>    pushes the Portworx images into remote container registry server
    load node1 [node2 [...]]  loads the images tarball to remote nodes  (note: ssh-access required)

OPTIONS:
    -I|--include <image>      specify additional images to include
    -E|--exclude <glob>       specify images to EXCLUDE  (e.g. -E '*csi*')
    -n|--dry-run              show commands instead of running
    -V|--version              print version of the script
    -v                        verbose output

LOAD-SPECIFIC OPTIONS:
    -e|--rsh <command>        specify the remote shell to use  (default $RSH)
    -L|--load-cmd <command>   specify the remote container-load command to use  (default $LOAD)
    -t <prefix>               specify temporary tarball filename  (default $TARBALL)
    --pks                     assume PKS environment; transfer images using 'bosh' command

EXAMPLES:

    # Pull images from default container registries, push them to custom registry server (default repositories)
    $ME pull push your-registry.company.com:5000

    # Pull images from default container registries, push them to custom registry server and portworx repository
    $ME pull
    $ME push your-registry.company.com:5000/portworx

    # Push images to password-protected remote registry, then import docker/podman configuration as kuberentes secret
    $CNT_CMD login your-registry.company.com:5000
    $ME pull
    $ME push your-registry.company.com:5000/portworx
    $ME import-secrets

    # Pull images, then load to given nodes using ssh
    $ME pull
    $ME load node1 node2 node33 node444

    # Pull images, then load to given nodes using ssh and root-account
    $ME -e "ssh -l root" pull load node1 node2 node33 node444

    # Load images to given nodes using ssh and password '5ecr3t'
    $ME -e "sshpass -p 5ecr3t ssh" load node1 node2 node33 node444

    # Pull ONLY busybox image, load it to given nodes
    $ME -E '*' -I docker.io/busybox:latest pull load node1 node2 node33 node444

_EOF
    exit $rc
}

[ $# -gt 0 ] || usage

while [ $# -gt 0 ]; do
    case "$1" in
        pull)
            pull_images
            ;;
        push)
            push_images_registry $2
            shift ;;
        load)
            shift
            load_images_nodes $@
            shift $#
            break ;;
        import-secrets)
            import_secrets
            ;;
        -e|--rsh)
            RSH=$2
            shift ;;
        -L|--load-cmd)
            LOAD=$2
            shift ;;
        -t)
            TARBALL=$2
            shift ;;
        -n|--dry-run)
            # dry-run mode
            CNT_CMD="dummy_cmd $CNT_CMD"
            K8S_CMD="dummy_cmd $K8S_CMD"
            LOAD='cat > /dev/null'
            DRYRUN=1
            ;;
        -I|--include)
            IMAGES="$IMAGES $2"
            shift ;;
        -E|--exclude)
            newIMAGES=""
            for img in $IMAGES; do
              case "$img" in
                $2) ;;    # skip
                *)  newIMAGES="$newIMAGES $img" ;;
              esac
            done
            IMAGES=$newIMAGES
            shift ;;
        --pks)
            [ -n "${BOSH_DEPLOYMENT+set}" ] || \
                fail 'PKS and bosh requires $BOSH_DEPLOYMENT environment variable to be set'
            RSH=bosh
            LOAD='DOCKER_HOST=unix:///var/vcap/sys/run/docker/docker.sock /var/vcap/packages/docker/bin/docker load -i'
            TARBALL=/tmp/px-agtmp.tar
            ;;
        -v)
            VERBOSE=$((VERBOSE+1))
            ;;
        -V|--version)
            echo "Portworx air-gapped images helper v2.6.2.1"
            shift $#
            break ;;
        -h|--help)
            usage
            break ;;
        --)
            shift
            break ;;
        *)
            break ;;
    esac
    shift
done

[ $# -eq 0 ] || fail "Unknown argument(s): $@"
