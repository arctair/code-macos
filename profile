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
    find ~/code -type d -name .git | while read -r git_dir; do
        repo_dir="$(dirname "$git_dir")"
        rel_path="${repo_dir#~/code/}"
        default_branch="$(git -C "$repo_dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')"
        current_branch="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"

        if [ -z "$default_branch" ]; then
            echo "$rel_path: skipped: no default branch (origin/HEAD not set)"
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
            git-prefixed "$rel_path" git -C "$repo_dir" pull --ff-only origin "$default_branch"
            continue
        fi

        echo "$rel_path: switching from $current_branch to $default_branch"
        git-prefixed "$rel_path" git -C "$repo_dir" checkout "$default_branch"
        git-prefixed "$rel_path" git -C "$repo_dir" reset --hard "origin/$default_branch"
    done
}