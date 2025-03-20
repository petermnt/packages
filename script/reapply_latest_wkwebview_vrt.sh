#!/usr/bin/env bash

set -euo pipefail

readonly TAG_PREFIX='webview_flutter_wkwebview-v'
readonly PUSH_REMOTE='origin'

push_changes=false
if [[ "${1:-}" == "--push" ]]; then
  push_changes=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--push]" >&2
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo 'Must be run inside a git repository.' >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo 'Working tree is not clean. Commit or stash changes first.' >&2
  exit 1
fi

echo 'Fetching upstream tags...'
git fetch upstream --tags

latest_vrt_tag=$(git tag --list "${TAG_PREFIX}*-vrt" --sort=version:refname | tail -n 1)
if [[ -z "${latest_vrt_tag}" ]]; then
  echo "No tags matching ${TAG_PREFIX}*-vrt were found." >&2
  exit 1
fi

latest_base_tag=$(git tag --list "${TAG_PREFIX}*" \
  | grep -E "^${TAG_PREFIX}[0-9]+\.[0-9]+\.[0-9]+$" \
  | sort -V \
  | tail -n 1)
if [[ -z "${latest_base_tag}" ]]; then
  echo "No base tags matching ${TAG_PREFIX}<semver> were found." >&2
  exit 1
fi

source_version=${latest_vrt_tag#${TAG_PREFIX}}
source_version=${source_version%-vrt}
source_base_tag="${TAG_PREFIX}${source_version}"

if ! git rev-parse -q --verify "refs/tags/${source_base_tag}" >/dev/null; then
  echo "Source base tag ${source_base_tag} does not exist." >&2
  exit 1
fi

if [[ "${latest_base_tag}" == "${source_base_tag}" ]]; then
  echo "Latest base tag (${latest_base_tag}) already has the newest vrt baseline (${latest_vrt_tag})." >&2
  exit 1
fi

mapfile -t vrt_commits < <(git rev-list --reverse "${source_base_tag}..${latest_vrt_tag}")
if [[ ${#vrt_commits[@]} -eq 0 ]]; then
  echo "No commits found between ${source_base_tag} and ${latest_vrt_tag}." >&2
  exit 1
fi

target_version=${latest_base_tag#${TAG_PREFIX}}
target_branch="vrt-overrides-${target_version}"
target_vrt_tag="${latest_base_tag}-vrt"

if git rev-parse -q --verify "refs/heads/${target_branch}" >/dev/null; then
  echo "Branch ${target_branch} already exists." >&2
  exit 1
fi

if git rev-parse -q --verify "refs/tags/${target_vrt_tag}" >/dev/null; then
  echo "Tag ${target_vrt_tag} already exists." >&2
  exit 1
fi

echo "Latest vrt tag:   ${latest_vrt_tag}"
echo "Latest base tag:  ${latest_base_tag}"
echo "Creating branch:  ${target_branch}"
echo "Creating tag:     ${target_vrt_tag}"

git switch -c "${target_branch}" "${latest_base_tag}"
git cherry-pick "${vrt_commits[@]}"
git tag "${target_vrt_tag}"

if [[ "${push_changes}" == true ]]; then
  echo "Pushing branch and tag to ${PUSH_REMOTE}..."
  git push "${PUSH_REMOTE}" "${target_branch}" "${target_vrt_tag}"
fi

echo 'Done.'
echo "Branch ${target_branch} points to $(git rev-parse --short HEAD)."
echo "Tag ${target_vrt_tag} points to $(git rev-parse --short "refs/tags/${target_vrt_tag}")."
