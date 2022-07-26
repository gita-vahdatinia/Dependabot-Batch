BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Pull in branch changes from dependabot PRs:
#   1. Switch to root of local GIT tree (may be a cross-repo directory)
#   2. Apply patch commits to package.json and Pipfile from each branch - we avoid yarn.lock due to merge issues
#   3. Run update `yarn` and `pipenv install` to finalize yarn.lock and Pipfile.lock changes
GIT_ROOT=$(git rev-parse --show-toplevel)
echo "Operating on GIT repo: ${GIT_ROOT}"
cd ${GIT_ROOT}

# Validate package.json and Pipfile are clean
PACKAGE_FILES=$(ls -C1 package.json Pipfile 2> /dev/null || true)
LOCK_FILES=$(ls -C1 yarn.lock Pipfile.lock 2> /dev/null || true)
CHANGED=$(git diff --name-only ${PACKAGE_FILES} ${LOCK_FILES} | tr -d '\n')
if [[ -n "${CHANGED}" ]]; then
  echo "${bldyel}WARNING: Changes detected in ${CHANGED} - some patches may fail to apply${txtdef}"
fi

git fetch > /dev/null

PATCHED=()
for br in $(echo "${LIST_OF_BRANCHES}" | sort); do
  # diff package.json and Pipfile from the remote dependabot branch and then apply as a local patch.
  echo "${txtbld}Patching: $br ${txtdef}"
  git diff "origin/${br}~...origin/${br}" -- ${PACKAGE_FILES} | git apply -C0 && PATCHED+=(${br}) || echo "${bldred}WARNING: Skipping failed patch ${br}${txtdef}"
done

echo ${PATCHED}
if [[ -z "${PATCHED[*]}" ]]; then
  echo "${bldred}ERROR: all patches failed ¯\_(ツ)_/¯"
  exit 1
fi

# Finalize tweaks to yarn.lock file by installing from package.json
if [[ "${PATCHED[*]}" == *"/npm_and_yarn/"* ]]; then
  echo "${txtbld}Finalizing yarn.lock updates${txtdef}"
  yarn install
fi

# Finalize Pipfile.lock file by installing from Pipfile
if [[ "${PATCHED[*]}" == *"/pip/"* ]]; then
  echo "${txtbld}Finalizing Pipfile.lock updates${txtdef}"
  pipenv install
fi

echo "${txtbld}Successfully patched: ${PATCHED[*]}${txtdef}"
git checkout -b ${BRANCH_TITLE}

TICK='`'
git commit -m "
Dependabot batched commit

Batched commits generated by: ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID} ${TICK}  ${PATCHED[*]}${TICK}

$(
  for br in "${PATCHED[@]}"; do
    git log --format=%B -n 1 origin/${br} | grep -v "Signed-off-by"
  done
)
------------------------------------------------------------------------------
" -- ${PACKAGE_FILES} ${LOCK_FILES}
GIT_PR_TITLE="Dependabot Batch generated by Run: ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID} ${TICK}  
${PATCHED[*]}${TICK}
------------------------------------------------------------------------------
"
GIT_COMMITS=$(
  for br in "${PATCHED[@]}"; do
    git log --format=%B -n 1 origin/${br} | grep -v "Signed-off-by"
  done
  ------------------------------------------------------------------------------
)
GITHUB_BODY="${GIT_PR_TITLE} \n\n${GIT_COMMITS}"

PR_TITLE=$(echo "${BRANCH_TITLE}" | tr "-" " " | tr "_" " " | tr "/" " ")
git push --set-upstream origin ${BRANCH_TITLE}

echo "------------------------------------------------------------------------------"
echo ${PR_TITLE}
echo ${GITHUB_REPOSITORY}
echo ${GITHUB_BODY}
echo ${BRANCH_TITLE}
echo ${GITHUB_TOKEN}
PR_HEAD="github-actions:${BRANCH_TITLE}"
echo ${PR_HEAD}

RESPONSE=$(curl --location --request POST \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls" \
  -H 'Accept: application/vnd.github+json' \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  --data-raw '{"title":"'"$PR_TITLE"'","body":"'"$GITHUB_BODY"'", "head":"'"$BRANCH_TITLE"'","base":"main"}')
PULL_NUMBER=$(echo "${RESPONSE}" | jq -r '.number // empty')
echo ${PULL_NUMBER}
echo ${RESPONSE}

if [[  -z "${PULL_NUMBER}" ]]; then
  echo "No PR Created"
  exit 1;
fi

PULL_NUMBER=$(echo "${RESPONSE}" | jq -r '.number // empty')
echo ${RESPONSE}
echo ${PULL_NUMBER}
# curl --location --request POST "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${PULL_NUMBER}/requested_reviewers" \
# --header 'Accept: application/vnd.github+json' \
# --header "Authorization: token $GITHUB_TOKEN" \
# --header 'Content-Type: application/json' \
# --data-raw '{"reviewers":["'"$GITHUB_ACTOR"'"]}'