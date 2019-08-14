#!/usr/bin/env bash

# Prerequisite
# Make sure you set secret enviroment variables in Travis CI
# TARGET_REPOSITORY
# API_TOKEN

set -ex

# Monitor Repository
target_repository="${TARGET_REPOSITORY}"

# My docker hub Repository
mirror_repository="hawsers/${target_repository}"

target_tags=(`curl -k -s -X GET https://gcr.io/v2/google_containers/${target_repository}/tags/list | jq -r '.tags[] | @sh'`)

# docker hub return paginated result
mirrored_tags=()
page=1

while [ $page -gt 0 ]
do     
    dockerhub_response=`curl -sL https://hub.docker.com/v2/repositories/${mirror_repository}/tags?page=${page}`

    next_page=`echo $dockerhub_response | jq  -r '.next'`

    if [ ${next_page//\'} != 'null' ]; then
        page=$((`echo $next_page | grep -o '[0-9]\+$'`))
    else
        page=0
    fi

    mirrored_tags+=(`echo $dockerhub_response | jq -r '.results[].name | @sh'`)
    # mirrored_tags+=(`curl -sL https://hub.docker.com/v2/repositories/${mirror_repository}/tags?page=${page} 2>/dev/null | jq -r '.results[].name | @sh'`)

done

missing_tags=()
for i in "${target_tags[@]}"; do
    skip=
    for j in "${mirrored_tags[@]}"; do
        [[ $i == $j ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || missing_tags+=("$i")
done

declare -p missing_tags

# Git setup
git status

# reAttach for Travis-CI
git remote rm origin
git remote add origin https://hawsers:${API_TOKEN}@github.com/hawsers/mirror-${target_repository}.git
git remote -v

git checkout master
git fetch --tags

limitTrigger=10
for i in "${missing_tags[@]}"; do
    #Check if tag exists
    # if [[ $(git tag -l ${i//\'}) ]]; then
    #     continue
    # else
        if [ $limitTrigger -gt 0 ]; then
            echo "FROM k8s.gcr.io/${target_repository}:${i//\'}" > Dockerfile
            git commit -a -m ${i//\'} --allow-empty

            git tag -f -a ${i//\'} -m "Auto Tag:${i//\'}"
            # MUST Push one by one
            git push -v -f origin ${i//\'}
            ((limitTrigger--))
        else
            break
        fi
    # fi
done

# do not push commits
# git push -v -f origin master