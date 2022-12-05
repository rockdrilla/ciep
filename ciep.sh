#!/bin/sh

## common shell functions: begin

log_verbose() {
	if [ $# = 0 ] ; then
		echo "# ${__CIEP_SOURCE}: $(date +'%Y-%m-%d %H:%M:%S %z')"
	else
		echo "# ${__CIEP_SOURCE}: $*"
	fi 1>&2
}
if [ -n "${CIEP_VERBOSE}" ] ; then
	log() { log_verbose "$@" ; }
else
	log() { : ;}
fi

have_cmd() { command -v "$1" >/dev/null 2>&1 ; }

## common shell functions: end

if [ -z "${__CIEP_SOURCE}" ] ; then

## ciep.sh itself

set -f

__CIEP_SOURCE="$0"

## PID1 handling
## "CIEP_INIT={no|false|0|pid1_prog[ args]}"
: "${CIEP_INIT:=dumb-init}"
case "${CIEP_INIT}" in
0 | [Nn][Oo] | [Ff][Aa][Ll][Ss][Ee])
	unset CIEP_INIT CIEP_INIT_ARGS
;;
*)
	case "${CIEP_INIT}" in
	*\ *)
		unset CIEP_INIT_ARGS
		read -r CIEP_INIT CIEP_INIT_ARGS <<-EOF
		${CIEP_INIT}
		EOF
	;;
	esac

	if ! have_cmd "${CIEP_INIT}" ; then
		log "pid1: ${CIEP_INIT} is not found"
		unset CIEP_INIT CIEP_INIT_ARGS
	fi

	## unexport variables
	__CIEP_TMPVAR=${CIEP_INIT} ; unset CIEP_INIT ; CIEP_INIT=${__CIEP_TMPVAR}
	__CIEP_TMPVAR=${CIEP_INIT_ARGS} ; unset CIEP_INIT_ARGS ; CIEP_INIT_ARGS=${__CIEP_TMPVAR}
	unset __CIEP_TMPVAR
;;
esac

## switching user
## "CIEP_RUNAS=user[:group[:runas_prog[ args]]]"
if [ -z "${CIEP_RUNAS}" ] ; then
	unset CIEP_RUNAS CIEP_RUNAS_BIN CIEP_RUNAS_ARGS
fi
while [ -n "${CIEP_RUNAS}" ] ; do
	IFS=: read -r CIEP_RUNAS_USER CIEP_RUNAS_GROUP CIEP_RUNAS_BIN <<-EOF
	${CIEP_RUNAS}
	EOF

	## readjust variable
	CIEP_RUNAS="${CIEP_RUNAS_USER}"
	if [ -n "${CIEP_RUNAS_GROUP}" ] ; then
		CIEP_RUNAS="${CIEP_RUNAS}:${CIEP_RUNAS_GROUP}"
	fi

	: "${CIEP_RUNAS_BIN:=su-exec}"
	case "${CIEP_RUNAS_BIN}" in
	*\ *)
		unset CIEP_RUNAS_ARGS
		read -r CIEP_RUNAS_BIN CIEP_RUNAS_ARGS <<-EOF
		${CIEP_RUNAS_BIN}
		EOF
	;;
	esac

	if ! have_cmd "${CIEP_RUNAS_BIN}" ; then
		log "runas: ${CIEP_RUNAS_BIN} is not found"
		unset CIEP_RUNAS_USER CIEP_RUNAS_GROUP CIEP_RUNAS_BIN CIEP_RUNAS_ARGS
		break
	fi

	## unexport variables
	__CIEP_TMPVAR=${CIEP_RUNAS_BIN} ; unset CIEP_RUNAS_BIN ; CIEP_RUNAS_BIN=${__CIEP_TMPVAR}
	__CIEP_TMPVAR=${CIEP_RUNAS_ARGS} ; unset CIEP_RUNAS_ARGS ; CIEP_RUNAS_ARGS=${__CIEP_TMPVAR}
	unset __CIEP_TMPVAR

	case "${CIEP_RUNAS_BIN}" in
	setpriv)
		## TODO: `setpriv' applet in busybox doesn't support these options!
		: "${CIEP_RUNAS_ARGS:=--init-groups}"
		CIEP_RUNAS_ARGS="${CIEP_RUNAS_ARGS}${CIEP_RUNAS_ARGS:+ }--reuid=${CIEP_RUNAS_USER}"
		if [ -n "${CIEP_RUNAS_GROUP}" ] ; then
			CIEP_RUNAS_ARGS="${CIEP_RUNAS_ARGS}${CIEP_RUNAS_ARGS:+ }--regid=${CIEP_RUNAS_GROUP}"
		fi
	;;
	*)	## `gosu', `su-exec' and maybe others
		CIEP_RUNAS_ARGS="${CIEP_RUNAS_ARGS}${CIEP_RUNAS_ARGS:+ }${CIEP_RUNAS_USER}"
		if [ -n "${CIEP_RUNAS_GROUP}" ] ; then
			CIEP_RUNAS_ARGS="${CIEP_RUNAS_ARGS}:${CIEP_RUNAS_GROUP}"
		fi
	;;
	esac

	unset CIEP_RUNAS_NAME CIEP_RUNAS_HOME CIEP_RUNAS_SHELL
	IFS=: read -r CIEP_RUNAS_NAME CIEP_RUNAS_HOME CIEP_RUNAS_SHELL <<-EOF
	$(
		if printf '%s' "${CIEP_RUNAS_USER}" | grep -E -q '^[0-9]+$' ; then
			grep -E "^[^:]+:[^:]*:${CIEP_RUNAS_USER}:" /etc/passwd
		else
			grep -E "^${CIEP_RUNAS_USER}:" /etc/passwd
		fi 2>/dev/null \
		| cut -d: -f'1,6,7'
	)
	EOF

	if [ -z "${CIEP_RUNAS_NAME}${CIEP_RUNAS_HOME}${CIEP_RUNAS_SHELL}" ] ; then
		unset CIEP_RUNAS_NAME CIEP_RUNAS_HOME CIEP_RUNAS_SHELL
		## no env adjustments are made
		break
	fi

	: "${CIEP_ENV_CMD:=env}"

	if [ -n "${CIEP_RUNAS_NAME}" ] ; then
		CIEP_ENV_ARGS="${CIEP_ENV_ARGS}${CIEP_ENV_ARGS:+ }USER=${CIEP_RUNAS_NAME} LOGNAME=${CIEP_RUNAS_NAME}"
		CIEP_RUNAS_USER=${CIEP_RUNAS_NAME}
	fi

	if [ -n "${CIEP_RUNAS_HOME}" ] ; then
		CIEP_ENV_ARGS="${CIEP_ENV_ARGS}${CIEP_ENV_ARGS:+ }HOME=${CIEP_RUNAS_HOME}"
	fi

	if [ -n "${CIEP_RUNAS_SHELL}" ] ; then
		CIEP_ENV_ARGS="${CIEP_ENV_ARGS}${CIEP_ENV_ARGS:+ }SHELL=${CIEP_RUNAS_SHELL}"
	fi

	break
done

## unexport variables
__CIEP_TMPVAR=${CIEP_ENV_CMD} ; unset CIEP_ENV_CMD ; CIEP_ENV_CMD=${__CIEP_TMPVAR}
__CIEP_TMPVAR=${CIEP_ENV_ARGS} ; unset CIEP_ENV_ARGS ; CIEP_ENV_ARGS=${__CIEP_TMPVAR}
unset __CIEP_TMPVAR

## switching user: last resort adjustments
: "${CIEP_RUNAS_USER:=$(id -un 2>/dev/null)}"
: "${CIEP_RUNAS_GROUP:=$(id -gn 2>/dev/null)}"
: "${CIEP_RUNAS_USER:=$(id -u)}"
: "${CIEP_RUNAS_GROUP:=$(id -g)}"
export CIEP_RUNAS_USER CIEP_RUNAS_GROUP

## run parts (if any)
while read -r f ; do
	[ -n "$f" ] || continue

	## skip any file named "*.-"
	case "$f" in
	*.-)
		if [ -f "/ciep.d/$f" ] ; then
			log "skipping: /ciep.d/$f"
		fi
		continue
	;;
	esac

	if [ -e "/ciep.user/$f.-" ] ; then
		log "local ignore: /ciep.d/$f is suppressed by /ciep.user/$f.-"
		continue
	fi

	if [ -f "/ciep.user/$f" ] ; then
		if [ -f "/ciep.d/$f" ] ; then
			log "local override: /ciep.user/$f replaces /ciep.d/$f"
		fi
		f="/ciep.user/$f"
	else
		f="/ciep.d/$f"
	fi

	case "$f" in
	*.envsh)
		log "sourcing $f"
		__CIEP_SOURCE="$f"
		. "$f"
		__CIEP_SOURCE="$0"
	;;
	*)
		if [ -x "$f" ] ; then
			log "running $f"

			__CIEP_SOURCE="$f" \
			"$f" "$@"
		else
			log "skipping $f - not executable"
		fi
	;;
	esac
done <<EOF
$(
	{
	find /ciep.d/ /ciep.user/ -follow -mindepth 1 -maxdepth 1 -type f \
	|| \
	find /ciep.d/ /ciep.user/ -mindepth 1 -maxdepth 1 -type f
	} 2>/dev/null \
	| grep -E -o '[^/]+$' \
	| { sort -u -V || sort -u ; } 2>/dev/null
)
EOF

exec \
	${CIEP_RUNAS_BIN} ${CIEP_RUNAS_ARGS} \
	${CIEP_ENV_CMD} ${CIEP_ENV_ARGS} \
	${CIEP_INIT} ${CIEP_INIT_ARGS} \
	"$@"

fi
