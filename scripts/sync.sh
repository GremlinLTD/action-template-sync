#!/usr/bin/env bash
set -euo pipefail

SYNC_BRANCH="chore/template-sync"
BOT_NAME="syncy-mcsyncface[bot]"
BOT_EMAIL="syncy-mcsyncface[bot]@users.noreply.github.com"

validate_inputs() {
  if [ -z "${TEMPLATE_REPO:-}" ]; then
    echo "::error::template-repo input is required"
    return 1
  fi
  if [ -z "${GH_TOKEN:-}" ]; then
    echo "::error::token input is required"
    return 1
  fi
}

clone_template() {
  local dest="$1"
  git clone --depth 1 --branch "${TEMPLATE_REF:-main}" \
    "https://x-access-token:${GH_TOKEN}@github.com/${TEMPLATE_REPO}.git" \
    "${dest}" 2>/dev/null
  git -C "${dest}" rev-parse HEAD
}

parse_manifest() {
  local manifest="$1"
  if [ ! -f "${manifest}" ]; then
    echo "::error::No .sync-manifest.yml found in ${TEMPLATE_REPO}@${TEMPLATE_REF:-main}"
    return 1
  fi
  sed -n 's/^[[:space:]]*-[[:space:]]*//p' "${manifest}"
}

parse_ignore() {
  local ignore_file="$1"
  if [ ! -f "${ignore_file}" ]; then
    return 0
  fi
  grep -v '^#' "${ignore_file}" | grep -v '^[[:space:]]*$' || true
}

is_ignored() {
  local file="$1"
  local ignored="$2"
  if [ -z "${ignored}" ]; then
    return 1
  fi
  echo "${ignored}" | grep -qxF "${file}"
}

compare_files() {
  local template_dir="$1"
  local sync_files="$2"
  local ignored="$3"
  local changed=""
  local new=""

  while IFS= read -r file; do
    [ -z "${file}" ] && continue

    if is_ignored "${file}" "${ignored}"; then
      echo "::notice::Skipping ignored file: ${file}"
      continue
    fi

    local template_file="${template_dir}/${file}"
    if [ ! -f "${template_file}" ]; then
      echo "::warning::File listed in manifest but missing from template: ${file}"
      continue
    fi

    if [ ! -f "${file}" ]; then
      new="${new}${file}"$'\n'
    elif ! diff -q "${template_file}" "${file}" > /dev/null 2>&1; then
      changed="${changed}${file}"$'\n'
    fi
  done <<< "${sync_files}"

  echo "CHANGED:${changed}NEW:${new}"
}

extract_changed() {
  local result="$1"
  echo "${result}" | sed -n 's/^CHANGED://p' | sed '/^NEW:/,$d' | sed '/^$/d'
}

extract_new() {
  local result="$1"
  echo "${result}" | sed -n '/^NEW:/,$ { s/^NEW://p }' | sed '/^$/d'
}

handle_no_changes() {
  local existing_pr
  existing_pr=$(gh pr list --head "${SYNC_BRANCH}" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)
  if [ -n "${existing_pr}" ]; then
    gh pr comment "${existing_pr}" --body "All template files are now in sync. This PR can be closed."
    echo "::notice::Commented on existing PR #${existing_pr} - files are in sync"
  else
    echo "::notice::All files are in sync. Nothing to do."
  fi
}

build_pr_body() {
  local changed="$1"
  local new="$2"
  local template_sha="$3"

  local body="## Template Sync"$'\n\n'
  body+="Synced from [\`${TEMPLATE_REPO}\`](https://github.com/${TEMPLATE_REPO})"
  body+=" @ \`${TEMPLATE_REF:-main}\`"
  body+=" ([${template_sha:0:7}](https://github.com/${TEMPLATE_REPO}/commit/${template_sha}))"
  body+=$'\n\n'

  if [ -n "${changed}" ]; then
    body+="### Changed files"$'\n'
    while IFS= read -r f; do
      [ -z "${f}" ] && continue
      body+="- \`${f}\`"$'\n'
    done <<< "${changed}"
    body+=$'\n'
  fi

  if [ -n "${new}" ]; then
    body+="### New files"$'\n'
    while IFS= read -r f; do
      [ -z "${f}" ] && continue
      body+="- \`${f}\`"$'\n'
    done <<< "${new}"
    body+=$'\n'
  fi

  body+="---"$'\n'
  body+="*This PR was created automatically by [action-template-sync](https://github.com/gremlinltd/action-template-sync).*"

  echo "${body}"
}

create_or_update_pr() {
  local pr_body="$1"
  local pr_title="chore: sync files from ${TEMPLATE_REPO}"
  local existing_pr
  existing_pr=$(gh pr list --head "${SYNC_BRANCH}" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)

  if [ -n "${existing_pr}" ]; then
    gh pr edit "${existing_pr}" --body "${pr_body}"
    echo "::notice::Updated existing PR #${existing_pr}"
  else
    gh pr create \
      --title "${pr_title}" \
      --body "${pr_body}" \
      --head "${SYNC_BRANCH}" \
      --label "${PR_LABEL:-template-sync}" 2>/dev/null || \
    gh pr create \
      --title "${pr_title}" \
      --body "${pr_body}" \
      --head "${SYNC_BRANCH}"
    echo "::notice::Created new sync PR"
  fi
}

main() {
  validate_inputs

  local template_dir
  template_dir=$(mktemp -d)
  trap 'rm -rf "${template_dir}"' EXIT

  echo "::group::Cloning ${TEMPLATE_REPO}@${TEMPLATE_REF:-main}"
  local template_sha
  template_sha=$(clone_template "${template_dir}")
  echo "Template SHA: ${template_sha}"
  echo "::endgroup::"

  echo "::group::Parsing manifest"
  local sync_files
  sync_files=$(parse_manifest "${template_dir}/.sync-manifest.yml")
  local file_count
  file_count=$(echo "${sync_files}" | grep -c . || true)
  echo "Found ${file_count} files in manifest"
  echo "::endgroup::"

  local ignored
  ignored=$(parse_ignore ".sync-ignore")

  echo "::group::Comparing files"
  local result
  result=$(compare_files "${template_dir}" "${sync_files}" "${ignored}")
  local changed
  changed=$(extract_changed "${result}")
  local new
  new=$(extract_new "${result}")
  echo "::endgroup::"

  if [ -z "${changed}" ] && [ -z "${new}" ]; then
    echo "All files are in sync."
    handle_no_changes
    exit 0
  fi

  echo "::group::Creating sync branch and copying files"
  git config user.name "${BOT_NAME}"
  git config user.email "${BOT_EMAIL}"
  git checkout -B "${SYNC_BRANCH}"

  local all_files="${changed}${new}"
  while IFS= read -r file; do
    [ -z "${file}" ] && continue
    mkdir -p "$(dirname "${file}")"
    cp "${template_dir}/${file}" "${file}"
    git add "${file}"
  done <<< "${all_files}"
  echo "::endgroup::"

  if git diff --cached --quiet; then
    echo "No staged changes after copy. Exiting."
    exit 0
  fi

  git commit -m "chore: sync files from ${TEMPLATE_REPO}

Synced from ${TEMPLATE_REPO}@${TEMPLATE_REF:-main} (${template_sha})"

  echo "::group::Pushing and creating PR"
  git push --force origin "${SYNC_BRANCH}"

  local pr_body
  pr_body=$(build_pr_body "${changed}" "${new}" "${template_sha}")
  create_or_update_pr "${pr_body}"
  echo "::endgroup::"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
