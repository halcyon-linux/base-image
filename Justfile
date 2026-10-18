export project_root := `git rev-parse --show-toplevel`
export git_branch := `git branch --show-current`
export latest := "44"
export default_image := "alcyone"
export default_target := "alcyone"

alias run := run-container

_default:
    @just --list

_container_mgr:
    @{{ project_root }}/just_scripts/container_mgr

_tag image:
    @echo {{ image }}-build

# Check Just Syntax
just-check:
    #!/usr/bin/bash
    find "${project_root}" -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f "$file"
    done
    just --unstable --fmt --check -f "${project_root}/Justfile"

# Fix Just Syntax
[private]
just-fix:
    #!/usr/bin/bash
    find "${project_root}" -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f "$file"
    done
    just --unstable --fmt -f "${project_root}/Justfile"

# Build image
build target="" image="":
    @{{ project_root }}/just_scripts/build-image {{ target }} {{ image }} 

# Run Container
run-container target="" image="":
    @{{ project_root }}/just_scripts/run-image {{ target }} {{ image }}

# List Images
list-images:
    @{{ project_root }}/just_scripts/manage-images list

# Clean Images
clean-images:
    @{{ project_root }}/just_scripts/manage-images clean
