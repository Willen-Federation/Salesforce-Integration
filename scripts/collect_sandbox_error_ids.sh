#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi
if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip is required" >&2
  exit 1
fi

REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
SINCE_DAYS="${1:-14}"
TMP_DIR="$(mktemp -d)"
OUT_DIR="${TMP_DIR}/out"
mkdir -p "${OUT_DIR}"

now_epoch="$(date -u +%s)"
since_epoch="$((now_epoch - SINCE_DAYS * 86400))"

artifact_json="${TMP_DIR}/artifacts.json"
gh api "repos/${REPO}/actions/artifacts?per_page=100" --paginate > "${artifact_json}"

filtered="${TMP_DIR}/filtered_artifacts.json"
jq -c --argjson since "${since_epoch}" '
  [ .artifacts[]
    | select(.name | startswith("sandbox-deploy-"))
    | select(.expired == false)
    | select((.created_at | fromdateiso8601) >= $since)
  ] | sort_by(.created_at)
' "${artifact_json}" > "${filtered}"

summary_md="${OUT_DIR}/sandbox-errorid-summary.md"
summary_csv="${OUT_DIR}/sandbox-errorid-summary.csv"

{
  echo "generated_at_utc,artifact_name,artifact_id,created_at,deploy_id,error_id,error_status_code"
} > "${summary_csv}"

{
  echo "# Sandbox UNKNOWN_EXCEPTION ErrorId Summary"
  echo
  echo "- Repository: ${REPO}"
  echo "- Window: last ${SINCE_DAYS} days"
  echo "- Generated (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')"
  echo
} > "${summary_md}"

count="$(jq 'length' "${filtered}")"
if [ "${count}" -eq 0 ]; then
  {
    echo "No sandbox artifacts found in this window."
  } >> "${summary_md}"
  echo "${OUT_DIR}"
  exit 0
fi

{
  echo "| Created At (UTC) | Artifact | Deploy ID | ErrorId | Status Code |"
  echo "|---|---|---|---|---|"
} >> "${summary_md}"

for idx in $(seq 0 $((count - 1))); do
  artifact_id="$(jq -r ".[$idx].id" "${filtered}")"
  artifact_name="$(jq -r ".[$idx].name" "${filtered}")"
  created_at="$(jq -r ".[$idx].created_at" "${filtered}")"

  zip_path="${TMP_DIR}/${artifact_id}.zip"
  extract_dir="${TMP_DIR}/${artifact_id}"
  mkdir -p "${extract_dir}"
  gh api "repos/${REPO}/actions/artifacts/${artifact_id}/zip" > "${zip_path}"
  unzip -qq -o "${zip_path}" -d "${extract_dir}" || true

  report_json="${extract_dir}/deploy-report.json"
  deploy_log="${extract_dir}/deploy-start.log"
  validate_log="${extract_dir}/validate.log"

  deploy_id=""
  error_id=""
  status_code=""

  if [ -f "${report_json}" ]; then
    deploy_id="$(jq -r '.result.id // empty' "${report_json}" 2>/dev/null || true)"
    status_code="$(jq -r '.result.details.componentFailures.errorStatusCode // .result.errorStatusCode // empty' "${report_json}" 2>/dev/null || true)"
    error_id="$(jq -r '.result.errorMessage // empty' "${report_json}" 2>/dev/null | grep -Eo '[0-9]+-[0-9]+ \(-?[0-9]+\)' | head -n1 || true)"
  fi

  if [ -z "${deploy_id}" ]; then
    deploy_id="$(grep -Eo 'Deploy ID: [A-Za-z0-9]+' "${deploy_log}" "${validate_log}" 2>/dev/null | tail -n1 | awk '{print $3}' || true)"
  fi
  if [ -z "${error_id}" ]; then
    error_id="$(grep -Eo '[0-9]+-[0-9]+ \(-?[0-9]+\)' "${deploy_log}" "${validate_log}" "${report_json}" 2>/dev/null | head -n1 || true)"
  fi
  if [ -z "${status_code}" ]; then
    status_code="$(grep -Eo 'UNKNOWN_EXCEPTION|[A-Z_]+_EXCEPTION' "${deploy_log}" "${validate_log}" "${report_json}" 2>/dev/null | head -n1 || true)"
  fi

  if [ -n "${error_id}" ] || [ -n "${status_code}" ]; then
    echo "${created_at},${artifact_name},${artifact_id},${created_at},${deploy_id},${error_id},${status_code}" >> "${summary_csv}"
    echo "| ${created_at} | ${artifact_name} | ${deploy_id:-N/A} | ${error_id:-N/A} | ${status_code:-N/A} |" >> "${summary_md}"
  fi
done

if [ "$(wc -l < "${summary_csv}")" -eq 1 ]; then
  echo "No matching ErrorId entries found in the selected artifacts." >> "${summary_md}"
fi

echo "${OUT_DIR}"
