set -e;

ref="refs/$1/commits"

existingTreeSha=$(curl -L \
  -H "Accept: application/vnd.github+json" \
  -s \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/$ref" | jq '.object.sha' -r)

if [[ $existingTreeSha == "null" ]]; then
  echo "Ref $ref doesn't exist"
  treeSha=$(curl -L \
        -X POST \
        --fail \
        -s \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/trees" \
        -d '{"tree":[{"mode": "100644", "path": "'"${GITHUB_SHA}"'", "content": "'"$(base64 -w0 coverage.txt)"'"}]}' | jq '.sha' -r)
  if [[ $treeSha == "null" ]]; then
    echo "failed to create new content tree"
    exit 1
  fi
  echo "Created new content tree $treeSha"
  curl -L \
        -X POST \
        --fail \
        -s \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs" \
        -d '{"ref":"'"$ref"'","sha":"'"${treeSha}"'"}'
  echo "Updated ref $ref to the new content tree"
else
  echo "Found existing ref $ref. Tree sha: $existingTreeSha"
  treeSha=$(curl -L \
        -X POST \
        --fail \
        -s \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/trees" \
        -d '{"tree":[{"mode": "100644", "path": "'"${GITHUB_SHA}"'", "content": "'"$(base64 -w0 coverage.txt)"'"}], "base_tree": "'"$existingTreeSha"'"}' | jq '.sha' -r)
  if [[ $treeSha == "null" ]]; then
    echo "failed to create new content tree from $existingTreeSha"
    exit 1
  fi
  echo "Created new content tree $treeSha"
  curl -L \
        -X PATCH \
        --fail \
        -s \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/$ref" \
        -d '{"sha":"'"${treeSha}"'"}' > /dev/null
  echo "Updated ref $ref to the new content tree"
fi