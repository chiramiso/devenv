#!/bin/bash

# Define the current directory and projects directory
CURRENT_DIR=$(pwd)
PROJECTS_DIR="$CURRENT_DIR/projects"

# Ensure the projects directory exists
mkdir -p "$PROJECTS_DIR"

# Get all directories in the parent directory, excluding the current directory
PARENT_DIR=$(dirname "$CURRENT_DIR")
FOLDERS=($(find "$PARENT_DIR" -maxdepth 1 -mindepth 1 -type d ! -path "$CURRENT_DIR"))

# Prompt the user for action
echo "Do you want to link all projects automatically or decide for each one?"
select choice in "Link All" "Ask for Each" "Cancel"; do
    case $choice in
        "Link All")
            for folder in "${FOLDERS[@]}"; do
                project_name=$(basename "$folder")
                ln -sfn "$folder" "$PROJECTS_DIR/$project_name"
                echo "Linked $project_name to $folder"
            done
            break
            ;;
        "Ask for Each")
            for folder in "${FOLDERS[@]}"; do
                project_name=$(basename "$folder")
                read -p "Do you want to link $project_name? (y/n): " response
                if [[ "$response" == "y" || "$response" == "Y" ]]; then
                    ln -sfn "$folder" "$PROJECTS_DIR/$project_name"
                    echo "Linked $project_name to $folder"
                else
                    echo "Skipped $project_name"
                fi
            done
            break
            ;;
        "Cancel")
            echo "Operation canceled."
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose 1, 2, or 3."
            ;;
    esac
done