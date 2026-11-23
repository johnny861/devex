#!/bin/zsh
#
# AWS profile/region helpers.
#
# These export into the current shell, which is why they are functions rather than scripts.
# The bash-my-aws CLIs cover resource operations; this file only covers "which account am I
# pointing at", which shell state alone can answer.

# List the profiles configured in ~/.aws/config.
aws-profiles() {
  local profiles
  profiles=$(aws --no-cli-pager configure list-profiles 2>/dev/null)
  if [[ -z $profiles ]]; then
    print -u2 "No AWS profiles found; check that ~/.aws/config exists and is configured."
    return 1
  fi
  print -r -- "$profiles"
}

# Set the session profile. With no argument, clear it.
#   $ asp prod
#   $ asp            # unset AWS_PROFILE / AWS_DEFAULT_PROFILE
asp() {
  local available_profiles

  available_profiles=$(aws-profiles) || return 1

  if [[ -z ${1:-} ]]; then
    unset AWS_DEFAULT_PROFILE AWS_PROFILE
    print "AWS profile cleared."
    return 0
  fi

  # -F: fixed string, -x: whole line, so profile names are matched literally.
  if ! print -r -- "$available_profiles" | grep -qxF -- "$1"; then
    print -u2 "Profile '$1' is not configured in ~/.aws/config."
    print -u2 "Available profiles:"
    print -u2 -- "$available_profiles"
    return 1
  fi

  export AWS_DEFAULT_PROFILE="$1" AWS_PROFILE="$1"
}

# Set the session region. With no argument, clear it.
#   $ asr eu-west-1
asr() {
  if [[ -z ${1:-} ]]; then
    unset AWS_DEFAULT_REGION AWS_REGION
    print "AWS region cleared."
    return 0
  fi
  export AWS_DEFAULT_REGION="$1" AWS_REGION="$1"
}

# List profiles, marking the active one.
alp() {
  local available_profiles active profile

  available_profiles=$(aws-profiles) || return 1
  active="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-default}}"

  print -r -- "$available_profiles" | while IFS= read -r profile; do
    if [[ $profile == "$active" ]]; then
      print -- "* $profile (active)"
    else
      print -- "  $profile"
    fi
  done
}
