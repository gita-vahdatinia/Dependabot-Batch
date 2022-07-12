
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
for br in $(echo "$@" | sort); do
  # diff package.json and Pipfile from the remote dependabot branch and then apply as a local patch.
  echo $br
done
