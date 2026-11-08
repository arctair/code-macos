#!/bin/sh

# Add GitHub CLI to PATH if not already present
if ! command -v gh >/dev/null 2>&1; then
    export PATH="$HOME/.local/share/gh_2.98.0_macOS_amd64/bin:$PATH"
fi

git-prefixed() {
    local rel_path="$1"
    shift
    "$@" 2>/dev/null | sed "s|^|$rel_path: |"
}

git-update() {
    local filter="$*"
    find ~/code -type d -name .git | while read -r git_dir; do
        repo_dir="$(dirname "$git_dir")"
        rel_path="${repo_dir#~/code/}"
        repo_name="$(basename "$repo_dir")"

        if [ -n "$filter" ]; then
            matched=0
            for pattern in $filter; do
                case "$rel_path" in
                    *"$pattern"*) matched=1; break ;;
                esac
            done
            if [ "$matched" -eq 0 ]; then
                continue
            fi
        fi
        default_branch="$(git -C "$repo_dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')"
        current_branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"

        if [ -z "$default_branch" ]; then
            echo "$rel_path: skipped: no default branch (origin/HEAD not set)"
            continue
        fi

        if [ -n "$(git -C "$repo_dir" status --porcelain 2>/dev/null)" ]; then
            echo "$rel_path: skipped: has uncommitted changes"
            continue
        fi

        git-prefixed "$rel_path" git -C "$repo_dir" fetch origin "$default_branch"

        local_head="$(git -C "$repo_dir" rev-parse "$default_branch" 2>/dev/null)"
        remote_head="$(git -C "$repo_dir" rev-parse "origin/$default_branch" 2>/dev/null)"

        if [ "$local_head" = "$remote_head" ]; then
            echo "$rel_path: skipped: already caught up"
            continue
        fi

        if [ "$default_branch" = "$current_branch" ]; then
            merge_base="$(git -C "$repo_dir" merge-base "$default_branch" "origin/$default_branch" 2>/dev/null)"
            local_sha="$(git -C "$repo_dir" rev-parse "$default_branch" 2>/dev/null)"
            remote_sha="$(git -C "$repo_dir" rev-parse "origin/$default_branch" 2>/dev/null)"

            if [ "$local_sha" = "$remote_sha" ]; then
                echo "$rel_path: skipped: already caught up"
                continue
            fi

            if [ "$remote_sha" = "$merge_base" ]; then
                echo "$rel_path: skipped: local branch is already based on latest remote"
                continue
            fi

            if [ "$local_sha" = "$merge_base" ]; then
                if git -C "$repo_dir" pull --rebase origin "$default_branch" >/dev/null 2>&1; then
                    echo "$rel_path: updated"
                    continue
                else
                    git -C "$repo_dir" rebase --abort 2>/dev/null
                    echo "$rel_path: skipped: rebase conflict, please resolve manually"
                    continue
                fi
            fi

            if git -C "$repo_dir" pull --rebase origin "$default_branch" >/dev/null 2>&1; then
                echo "$rel_path: updated"
                continue
            else
                git -C "$repo_dir" rebase --abort 2>/dev/null
                echo "$rel_path: skipped: rebase conflict, please resolve manually"
                continue
            fi
        fi

        if [ "$current_branch" = "HEAD" ]; then
            current_sha="$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null)"
            echo "$rel_path: switching from detached HEAD ($current_sha) to $default_branch"
        else
            echo "$rel_path: switching from $current_branch to $default_branch"
        fi
        git-prefixed "$rel_path" git -C "$repo_dir" checkout "$default_branch"
        git-prefixed "$rel_path" git -C "$repo_dir" reset --hard "origin/$default_branch"
    done
}