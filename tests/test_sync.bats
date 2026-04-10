#!/usr/bin/env bats

setup() {
  # Source the sync script to get access to functions
  source "${BATS_TEST_DIRNAME}/../scripts/sync.sh" 2>/dev/null || true

  # Create temp directories for test isolation
  TEST_DIR=$(mktemp -d)
  TEMPLATE_DIR=$(mktemp -d)
  DOWNSTREAM_DIR=$(mktemp -d)

  # Set defaults for env vars the script expects
  export TEMPLATE_REPO="gremlinltd/test-template"
  export TEMPLATE_REF="main"
  export GH_TOKEN="fake-token"
  export PR_LABEL="template-sync"
}

teardown() {
  rm -rf "${TEST_DIR}" "${TEMPLATE_DIR}" "${DOWNSTREAM_DIR}"
}

# --- parse_manifest tests ---

@test "parse_manifest extracts file paths from manifest" {
  local result
  result=$(parse_manifest "${BATS_TEST_DIRNAME}/fixtures/manifest.yml")
  echo "${result}" | grep -qxF "CONTRIBUTING.md"
  echo "${result}" | grep -qxF "SECURITY.md"
  echo "${result}" | grep -qxF "LICENSE"
  echo "${result}" | grep -qxF ".github/workflows/stale-prs.yml"
  echo "${result}" | grep -qxF ".github/ISSUE_TEMPLATE/bug_report.yml"
}

@test "parse_manifest returns correct number of files" {
  local result
  result=$(parse_manifest "${BATS_TEST_DIRNAME}/fixtures/manifest.yml")
  local count
  count=$(echo "${result}" | grep -c .)
  [ "${count}" -eq 5 ]
}

@test "parse_manifest fails when manifest is missing" {
  run parse_manifest "${TEST_DIR}/nonexistent.yml"
  [ "${status}" -ne 0 ]
}

# --- parse_ignore tests ---

@test "parse_ignore extracts paths, skipping comments and blanks" {
  local result
  result=$(parse_ignore "${BATS_TEST_DIRNAME}/fixtures/sync-ignore")
  local count
  count=$(echo "${result}" | grep -c .)
  [ "${count}" -eq 2 ]
  echo "${result}" | grep -qxF "CONTRIBUTING.md"
  echo "${result}" | grep -qxF ".github/ISSUE_TEMPLATE/bug_report.yml"
}

@test "parse_ignore returns empty for missing file" {
  local result
  result=$(parse_ignore "${TEST_DIR}/nonexistent")
  [ -z "${result}" ]
}

# --- is_ignored tests ---

@test "is_ignored returns 0 for ignored file" {
  local ignored=$'CONTRIBUTING.md\nSECURITY.md'
  is_ignored "CONTRIBUTING.md" "${ignored}"
}

@test "is_ignored returns 1 for non-ignored file" {
  local ignored=$'CONTRIBUTING.md\nSECURITY.md'
  run is_ignored "LICENSE" "${ignored}"
  [ "${status}" -ne 0 ]
}

@test "is_ignored returns 1 for empty ignore list" {
  run is_ignored "LICENSE" ""
  [ "${status}" -ne 0 ]
}

# --- compare_files tests ---

@test "compare_files detects changed files" {
  mkdir -p "${TEMPLATE_DIR}"
  echo "new content" > "${TEMPLATE_DIR}/file.txt"

  cd "${DOWNSTREAM_DIR}"
  echo "old content" > "file.txt"

  local result
  result=$(compare_files "${TEMPLATE_DIR}" "file.txt" "")
  local changed
  changed=$(extract_changed "${result}")
  echo "${changed}" | grep -qxF "file.txt"
}

@test "compare_files detects new files" {
  mkdir -p "${TEMPLATE_DIR}"
  echo "content" > "${TEMPLATE_DIR}/new-file.txt"

  cd "${DOWNSTREAM_DIR}"

  local result
  result=$(compare_files "${TEMPLATE_DIR}" "new-file.txt" "")
  local new
  new=$(extract_new "${result}")
  echo "${new}" | grep -qxF "new-file.txt"
}

@test "compare_files detects identical files as no change" {
  mkdir -p "${TEMPLATE_DIR}"
  echo "same content" > "${TEMPLATE_DIR}/file.txt"

  cd "${DOWNSTREAM_DIR}"
  echo "same content" > "file.txt"

  local result
  result=$(compare_files "${TEMPLATE_DIR}" "file.txt" "")
  local changed
  changed=$(extract_changed "${result}")
  local new
  new=$(extract_new "${result}")
  [ -z "${changed}" ]
  [ -z "${new}" ]
}

@test "compare_files skips ignored files" {
  mkdir -p "${TEMPLATE_DIR}"
  echo "new content" > "${TEMPLATE_DIR}/file.txt"

  cd "${DOWNSTREAM_DIR}"
  echo "old content" > "file.txt"

  local result
  result=$(compare_files "${TEMPLATE_DIR}" "file.txt" "file.txt")
  local changed
  changed=$(extract_changed "${result}")
  local new
  new=$(extract_new "${result}")
  [ -z "${changed}" ]
  [ -z "${new}" ]
}

@test "compare_files warns on missing template file" {
  cd "${DOWNSTREAM_DIR}"
  local result
  result=$(compare_files "${TEMPLATE_DIR}" "missing.txt" "")
  local changed
  changed=$(extract_changed "${result}")
  local new
  new=$(extract_new "${result}")
  [ -z "${changed}" ]
  [ -z "${new}" ]
}

# --- build_pr_body tests ---

@test "build_pr_body includes changed files" {
  local body
  body=$(build_pr_body "file1.txt" "" "abc1234567890")
  echo "${body}" | grep -q "file1.txt"
  echo "${body}" | grep -q "Changed files"
}

@test "build_pr_body includes new files" {
  local body
  body=$(build_pr_body "" "new-file.txt" "abc1234567890")
  echo "${body}" | grep -q "new-file.txt"
  echo "${body}" | grep -q "New files"
}

@test "build_pr_body includes template SHA" {
  local body
  body=$(build_pr_body "file.txt" "" "abc1234567890def1234567890abc1234567890ab")
  echo "${body}" | grep -q "abc1234"
}

@test "build_pr_body includes template repo link" {
  local body
  body=$(build_pr_body "file.txt" "" "abc1234567890")
  echo "${body}" | grep -q "gremlinltd/test-template"
}

# --- validate_inputs tests ---

@test "validate_inputs succeeds with required vars" {
  validate_inputs
}

@test "validate_inputs fails without TEMPLATE_REPO" {
  unset TEMPLATE_REPO
  run validate_inputs
  [ "${status}" -ne 0 ]
}

@test "validate_inputs fails without GH_TOKEN" {
  unset GH_TOKEN
  run validate_inputs
  [ "${status}" -ne 0 ]
}
