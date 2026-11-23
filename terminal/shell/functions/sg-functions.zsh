#!/bin/zsh
#
# sg-functions
#
# Modify EC2 security group rules. Designed to be stacked with pipes:
#
#     $ instances wordpress | instance-sg | sg-rule-add tcp 443 0.0.0.0/0 | sg-rules
#
# Group IDs are taken from `--group-id` flags or, if none are given, from
# the first `sg-` token on each line of STDIN (so `instance-sg` output works).
# Each function prints the affected group IDs to STDOUT so the next
# command in the pipe can pick them up; status messages go to STDERR.
#
# sg-rule-remove can also take rule IDs (`sgr-`), so a subset of rules
# can be picked with grep:
#
#     $ sg-rules sg-0a1b2c3d4e5f67890 | grep 0.0.0.0/0 | sg-rule-remove


# Private helpers. These used to live in a local copy of bash-my-aws internals
# (shared-bma-functions.zsh); inlining the three that are actually used removes the
# dependency and drops the dead/deprecated parts of that file.

__sg_error() { print -u2 -- "ERROR: $*"; return 1 }

__sg_usage() { print -u2 -- "USAGE: ${funcstack[2]:-sg-functions} $*" }

__sg_columnise() {
  # bma's columnise behaviour: leave raw tabs when the consumer is not a terminal.
  if [[ ${BMA_COLUMNISE_ONLY_WHEN_TERMINAL_PRESENT:-} == true ]] && ! [[ -t 1 ]]; then
    cat
  else
    column -t -s $'\t'
  fi
}


__sg_skim_group_ids() {

  # Print unique security group IDs from args, or else from the first `sg-`
  # token of each STDIN line (STDIN is ignored when args are given, so
  # non-interactive callers like cron don't block waiting on it)

  {
    [[ $# -gt 0 ]] && printf '%s\n' "$@" && return
    [[ -t 0 ]] || awk '{ if (match($0, /(^|[[:space:]])sg-[0-9a-f]+/)) { s = substr($0, RSTART, RLENGTH); gsub(/[[:space:]]/, "", s); print s } }'
  } | awk 'NF && !seen[$0]++'
}

__sg_ip_permissions() {

  # Build the --ip-permissions JSON for a single rule
  #
  #     USAGE: __sg_ip_permissions protocol port[-port]|all source [description]

  local protocol="$1" ports="$2" source="$3" description="$4"
  local from_port to_port json_desc=""

  [[ $protocol == all ]] && protocol=-1
  [[ -n $description ]] && json_desc=$(printf ',"Description":"%s"' "$(printf '%s' "$description" | sed 's/[\\"]/\\&/g')")

  local json="{\"IpProtocol\":\"${protocol}\""
  if [[ $protocol != -1 && $ports != all ]]; then
    from_port=${ports%-*}
    to_port=${ports#*-}
    [[ $from_port =~ ^-?[0-9]+$ && $to_port =~ ^-?[0-9]+$ ]] ||
      { __sg_error "invalid port '$ports' (use 443, 8000-8080 or all)"; return 1; }
    json+=",\"FromPort\":${from_port},\"ToPort\":${to_port}"
  fi

  case "$source" in
    sg-*)  json+=",\"UserIdGroupPairs\":[{\"GroupId\":\"${source}\"${json_desc}}]" ;;
    pl-*)  json+=",\"PrefixListIds\":[{\"PrefixListId\":\"${source}\"${json_desc}}]" ;;
    *:*/*) json+=",\"Ipv6Ranges\":[{\"CidrIpv6\":\"${source}\"${json_desc}}]" ;;
    */*)   json+=",\"IpRanges\":[{\"CidrIp\":\"${source}\"${json_desc}}]" ;;
    *)     __sg_error "invalid source '$source' (use a CIDR, sg-id or pl-id)"; return 1 ;;
  esac

  printf '%s}' "$json"
}

__sg_rule_change() {

  # Shared implementation for sg-rule-add / sg-rule-remove
  #
  #     USAGE: __sg_rule_change authorize|revoke [--egress] [--dry-run] [--group-id sg-id]... protocol port source [description]

  local action="$1"; shift
  local direction=ingress dry_run="" group_args=() rule=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --egress)   direction=egress ;;
      --dry-run)  dry_run=--dry-run ;;
      --group-id) group_args+=("$2"); shift ;;
      *)          rule+=("$1") ;;
    esac
    shift
  done

  if [[ ${#rule[@]} -lt 3 ]]; then
    echo "USAGE: ${FUNCNAME[1]} [--egress] [--dry-run] [--group-id sg-id]... protocol|all port[-port]|all cidr|sg-id|pl-id [description]" >&2
    return 1
  fi

  local ip_permissions
  ip_permissions=$(__sg_ip_permissions "${rule[@]}") || return 1

  local group_ids=$(__sg_skim_group_ids "${group_args[@]}")
  [[ -z $group_ids ]] && __sg_error "no security group IDs given (pipe them in or use --group-id)" && return 1

  local group_id output rc=0
  for group_id in $group_ids; do
    if output=$(aws ec2 "${action}-security-group-${direction}" \
                  --group-id "$group_id"                       \
                  --ip-permissions "$ip_permissions"           \
                  $dry_run 2>&1); then
      echo "${action} ${direction} ${rule[*]:0:3} on ${group_id}: ok" >&2
    elif [[ $output == *DryRunOperation* ]]; then
      echo "${action} ${direction} ${rule[*]:0:3} on ${group_id}: dry run ok" >&2
    elif [[ $output == *InvalidPermission.Duplicate* ]]; then
      echo "${action} ${direction} ${rule[*]:0:3} on ${group_id}: already exists" >&2
    elif [[ $output == *InvalidPermission.NotFound* ]]; then
      echo "${action} ${direction} ${rule[*]:0:3} on ${group_id}: not found" >&2
    else
      echo "${action} ${direction} ${rule[*]:0:3} on ${group_id}: FAILED" >&2
      echo "$output" >&2
      rc=1
    fi
    echo "$group_id"
  done

  return $rc
}

__sg_rule_remove_ids() {

  # Remove rules by rule ID. Looks up each rule's group and direction,
  # then revokes them in one call per group and direction.
  #
  #     USAGE: __sg_rule_remove_ids [--dry-run] sgr-id [sgr-id]...

  local dry_run=""
  [[ $1 == --dry-run ]] && dry_run=--dry-run && shift

  local rules
  rules=$(
    aws ec2 describe-security-group-rules \
      --security-group-rule-ids "$@"      \
      --output text                       \
      --query "SecurityGroupRules[].[GroupId, IsEgress, SecurityGroupRuleId]"
  ) || return 1

  local group_id is_egress rule_ids direction output rc=0
  while IFS=$'\t' read -r group_id is_egress rule_ids; do
    [[ $is_egress == True ]] && direction=egress || direction=ingress
    if output=$(aws ec2 "revoke-security-group-${direction}" \
                  --group-id "$group_id"                    \
                  --security-group-rule-ids $rule_ids       \
                  $dry_run 2>&1); then
      echo "revoke ${direction} ${rule_ids} on ${group_id}: ok" >&2
    elif [[ $output == *DryRunOperation* ]]; then
      echo "revoke ${direction} ${rule_ids} on ${group_id}: dry run ok" >&2
    else
      echo "revoke ${direction} ${rule_ids} on ${group_id}: FAILED" >&2
      echo "$output" >&2
      rc=1
    fi
    echo "$group_id"
  done < <(
    # Group rule IDs by group and direction: "sg-id<TAB>True|False<TAB>sgr-a sgr-b"
    awk -F'\t' -v OFS='\t' '
      { key = $1 OFS $2; ids[key] = (key in ids) ? ids[key] " " $3 : $3 }
      END { for (key in ids) print key, ids[key] }' <<< "$rules" |
    LC_ALL=C sort
  )

  return $rc
}

sg-rule-add() {

  # Add a rule to security group(s)
  #
  #     USAGE: sg-rule-add [--egress] [--dry-run] [--group-id sg-id]... protocol|all port[-port]|all cidr|sg-id|pl-id [description]
  #
  #     $ sg-rule-add --group-id sg-0a1b2c3d4e5f67890 tcp 443 0.0.0.0/0 "https"
  #     $ instances wordpress | instance-sg | sg-rule-add tcp 22 203.0.113.4/32 "office" | sg-rules

  __sg_rule_change authorize "$@"
}

sg-rule-remove() {

  # Remove rules from security group(s), either by rule spec or by rule ID.
  #
  # By rule spec, the rule must match exactly (protocol, ports and source);
  # description is ignored:
  #
  #     USAGE: sg-rule-remove [--egress] [--dry-run] [--group-id sg-id]... protocol|all port[-port]|all cidr|sg-id|pl-id
  #
  #     $ instances wordpress | instance-sg | sg-rule-remove tcp 22 0.0.0.0/0 | sg-rules
  #
  # By rule ID, given as args or as the `sgr-` token on each STDIN line
  # (direction and group are looked up, so --egress/--group-id don't apply):
  #
  #     USAGE: sg-rule-remove [--dry-run] [sgr-id]...
  #
  #     $ sg-rules sg-0a1b2c3d4e5f67890 | grep 0.0.0.0/0 | sg-rule-remove --dry-run

  local arg dry_run="" positional=0 rule_ids=()
  for arg in "$@"; do
    case "$arg" in
      --dry-run) dry_run=--dry-run ;;
      sgr-*)     rule_ids+=("$arg"); (( positional++ )) ;;
      --*)       ;;
      *)         (( positional++ )) ;;
    esac
  done

  # Any positional arg that isn't a rule ID means a rule spec
  if [[ $positional -gt ${#rule_ids[@]} ]]; then
    __sg_rule_change revoke "$@"
    return
  fi

  if [[ ${#rule_ids[@]} -eq 0 ]] && ! [[ -t 0 ]]; then
    rule_ids=($(grep -oE 'sgr-[0-9a-f]+'))
  fi
  rule_ids=($(printf '%s\n' "${rule_ids[@]}" | awk 'NF && !seen[$0]++'))

  if [[ ${#rule_ids[@]} -eq 0 ]]; then
    echo "USAGE: sg-rule-remove [--egress] [--dry-run] [--group-id sg-id]... protocol|all port[-port]|all cidr|sg-id|pl-id" >&2
    echo "       sg-rule-remove [--dry-run] sgr-id [sgr-id]...   (or pipe in lines containing sgr- IDs)" >&2
    return 1
  fi

  __sg_rule_remove_ids $dry_run "${rule_ids[@]}"
}

sg-rules() {

  # List rules of security group(s)
  #
  #     USAGE: sg-rules [--header] sg-id [sg-id]
  #
  #     $ sg-rules --header sg-0a1b2c3d4e5f67890
  #     GROUP_ID              RULE_ID                DIRECTION  PROTOCOL  FROM  TO   SOURCE     DESCRIPTION
  #     sg-0a1b2c3d4e5f67890  sgr-0123456789abcdef0  ingress    tcp       443   443  0.0.0.0/0  https
  #     sg-0a1b2c3d4e5f67890  sgr-0fedcba9876543210  egress     all       all   all  0.0.0.0/0  None

  local header="" args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --header) header=1 ;;
      *)        args+=("$1") ;;
    esac
    shift
  done

  local group_ids=$(__sg_skim_group_ids "${args[@]}")
  [[ -z $group_ids ]] && __sg_usage "[--header] sg-id [sg-id]" && return 1

  aws ec2 describe-security-group-rules                            \
    --filters "Name=group-id,Values=$(echo $group_ids | tr ' ' ',')" \
    --output text                                                  \
    --query "
      SecurityGroupRules[][
        GroupId,
        SecurityGroupRuleId,
        IsEgress,
        IpProtocol,
        FromPort,
        ToPort,
        CidrIpv4 || CidrIpv6 || ReferencedGroupInfo.GroupId || PrefixListId,
        Description
      ]" |
  awk -F'\t' -v OFS='\t' '{
    $3 = ($3 == "True") ? "egress" : "ingress"
    if ($4 == "-1") $4 = "all"
    if ($5 == "-1") $5 = "all"
    if ($6 == "-1") $6 = "all"
    print
  }' |
  LC_ALL=C sort -t$'\t' -k1,1 -k3,3r |
  {
    [[ -n $header ]] && printf 'GROUP_ID\tRULE_ID\tDIRECTION\tPROTOCOL\tFROM\tTO\tSOURCE\tDESCRIPTION\n'
    cat
  } |
  __sg_columnise
}
