#!/bin/sh
############################################################################
#   Copyright (c) Hubert Bukowski. All rights reserved.
#   Licensed under the MIT License.
#   See License.txt in the project root for full license information.
#===========================================================================
#   This script makes extracts semantic version from the current repository
#   tree via applied version tags and untagged commit messages.
############################################################################
exec 3>&1

#===========================================================================
#   Configuration
#===========================================================================
SUBDIRECTORY_OK='Yes'
OPTIONS_KEEPDASHDASH=
OPTIONS_STUCKLONG=
OPTIONS_SPEC='git semver [options]
--
b,no-branch           disables branch information build metadata generation.
a,no-hash             disables commit SHA information build metadata generation.
t,no-timestamp        disables timestamp information build metadata generation.
l,no-local            disables localicity information build metadata generation.
p,no-pre-relase       disables pre-release version generation.
s,single-step         increments version by single step using most relevant commited changes.
tag-pattern=          pattern for version tag matching.
major-pattern=        commit message pattern for major changes.
minor-pattern=        commit message pattern for minor changes.
patch-pattern=        commit message pattern for patches.
v,verbose             diagnostic message logging.
'
. git-sh-setup

#===========================================================================
#   Initializes script variables and parameters.
#===========================================================================
no_branch=
no_hash=
no_timestamp=
no_local=
no_pre_relase=
single_step=
tag_pattern='^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
major_pattern='Breaking:*'
minor_pattern='Feature:*'
patch_pattern='*'
verbose=

while test $# != 0
do
    case "$1" in
    -b|--no-branch)
        no_branch=1
        ;;
    -a|--no-hash)
        no_hash=1
        ;;
    -t|--no-timestamp)
        no_timestamp=1
        ;;
    -l|--no-local)
        no_local=1
        ;;
    -p|--no-pre-release)
        no_pre_release=1
        ;;
    -s|--single-step)
        single_step=1
        ;;
    --tag-pattern)
        shift
        tag_pattern=$(echo $1 | sed -e 's/()/([0-9]+)\.([0-9]+)\.([0-9]+)/g')
        ;;
    --major-pattern)
        shift
        major_pattern=$1
        ;;
    --minor-pattern)
        shift
        minor_pattern=$1
        ;;
    --patch-pattern)
        shift
        patch_pattern=$1
        ;;
    -v|--verbose)
        verbose=1
        ;;
    --)
        shift
        break
        ;;
    *)
        usage
        ;;
    esac
    shift
done

#===========================================================================
#   Main script procedure.
#===========================================================================
function main() {
	local major=0
	local minor=1
	local patch=0

	last_versioned_commit="$(git describe --tags --abbrev=0 --match '?*.?*.?*' --always)"

	if [[ "$last_versioned_commit" =~ $tag_pattern ]]; then
		verbose "Version tag has been found: $last_versioned_commit."
		major=${BASH_REMATCH[1]}
		minor=${BASH_REMATCH[2]}
		patch=${BASH_REMATCH[3]}
	else
		verbose "Version tag has not been found."
		last_versioned_commit="$(git rev-list --max-parents=0 HEAD)"
	fi

	verbose "Last versioned commit: $last_versioned_commit"
	commits="$(git rev-list $last_versioned_commit..HEAD --reverse | awk '{$1=$1};NF' )"

	if [[ -n $commits ]]; then
		local changes=0
		while IFS= read -r commit ; do
			if [[ -n $commit ]]; then
				verbose "Analyzing commit $commit"
				case "$(git show -s --format=%s $commit)" in
					$major_pattern)
						changes=3
						;;
					$minor_pattern)
						if (( $changes < 2 )); then
							changes=2
						fi
						;;
					$patch_pattern)
						if (( $changes < 1 )); then changes=1; fi
						;;
				esac

				if [[ "$cumulative" -ne 1 ]]; then
					increment_version $changes
					changes=0
				fi
			fi
		done <<< "$(echo -e "$commits")"
		if [[ "$cumulative" -eq 1 ]]; then increment_version $changes; fi
	fi

	local semver="$major.$minor.$patch"

	if [[ -z $no_pre_release ]] && [[ -n $commits ]]; then
		local commit_count="$(echo "$commits" | grep -c '^')"
		if [[ $commit_count -gt 0 ]]; then semver="$semver-beta.$commit_count"; fi
	fi

	if [[ -z $no_local ]]; then
		if [[ $(git status --porcelain) ]]; then
			semver="$semver-local"
		fi
	fi

	if [[ -z $no_branch ]]; then
		semver="$semver+Branch.$(git rev-parse --abbrev-ref HEAD)"
	fi

	if [[ -z $no_hash ]]; then
		semver="$semver+Hash.$(git rev-parse HEAD)"
	fi

	if [[ -z $no_timestamp ]]; then
		semver="$semver+Timestamp.$(date -u +%Y%m%d-%H%M%S.%N)"
	fi

	echo $semver
}


#===========================================================================
#   Increments current semantic version components.
#---------------------------------------------------------------------------
#   PARAMETERS:
#       $change
#           Impact of the commit:
#               0 - no changes
#               1 - patch changes
#               2 - feature changes
#               3 - breaking changes
#---------------------------------------------------------------------------
#   READS:
#---------------------------------------------------------------------------
#   MODIFIES:
#       $major
#           Increments variable if $change represents a breaking changes.
#
#       $minor
#           Increments variable if $change represents a feature changes.
#
#       $patch
#           Increments variable if $change represents a patch changes.
#---------------------------------------------------------------------------
#   ECHOES:
#===========================================================================
function increment_version() {
    local change=$1

    if [[ "$change" -eq 3 ]]; then
		verbose "Incrementing major version."
        major=$(($major + 1))
        minor=0
        patch=0
    fi

	if [[ "$change" -eq 2 ]]; then
		verbose "Incrementing minor version."
        minor=$(($minor + 1))
        patch=0
    fi

	if [[ "$change" -eq 1 ]]; then
		verbose "Incrementing patch version."
        patch=$(($patch + 1))
    fi
}


#===========================================================================
#   Logs diagnostic messages when verbose parameter is used.
#---------------------------------------------------------------------------
#   PARAMETERS:
#       $message
#           Diagnostic message.
#---------------------------------------------------------------------------
#   READS:
#       $verbose
#---------------------------------------------------------------------------
#   MODIFIES:
#---------------------------------------------------------------------------
#   ECHOES:
#===========================================================================
function verbose() {
    local message=$@

	if [[ "$verbose" -eq 1 ]]; then
		printf "%b\n" "$message" >&3
	fi
}


#===========================================================================
#   Script start
#===========================================================================
main "$@"
