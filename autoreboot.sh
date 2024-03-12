#!/bin/bash

# Check if the system is Debian or Ubuntu
check_system() {
    local distro=$(lsb_release -i | cut -f 2)
    if [[ "$distro" != "Debian" && "$distro" != "Ubuntu" ]]; then
        echo "This script only supports Debian and Ubuntu."
        exit 1
    fi
}

# Function to install cron
install_cron() {
    echo "Attempting to install cron..."
    sudo apt-get update
    sudo apt-get install -y cron
    if ! systemctl is-active --quiet cron; then
        echo "Failed to install or start cron."
        exit 1
    fi
}

# Check if cron is installed and running
if ! command -v cron >/dev/null 2>&1 || ! systemctl is-active --quiet cron; then
    echo "cron is not installed or not running."
    read -p "Would you like to install cron? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            install_cron
            ;;
        *)
            echo "This script requires cron to run."
            exit 1
            ;;
    esac
fi

# Function to add a new reboot task with a descriptive comment
add_reboot_task() {
    local frequency day hour minute schedule comment

    # Get frequency
    while true; do
        read -p "Choose the frequency of the reboot task (1. Monthly, 2. Weekly, 3. Daily): " frequency
        if [[ $frequency =~ ^[1-3]$ ]]; then
            break
        else
            echo "Invalid input. Please enter 1, 2, or 3."
        fi
    done

    # Get day, hour, minute based on frequency
    case $frequency in
        1) # Monthly
            while true; do
                read -p "Enter the day of the month (1-28): " day
                if [[ $day =~ ^[1-9]$|^1[0-9]$|^2[0-8]$ ]]; then
                    break
                else
                    echo "Invalid day. Please enter a number between 1 and 28."
                fi
            done
            ;;
        2) # Weekly
            while true; do
                read -p "Enter the day of the week (1-7, where 1 is Monday): " day
                if [[ $day =~ ^[1-7]$ ]]; then
                    break
                else
                    echo "Invalid day. Please enter a number between 1 and 7."
                fi
            done
            ;;
        3) # Daily
            day="*"
            ;;
    esac

    # Get hour
    while true; do
        read -p "Enter the hour for reboot (0-23): " hour
        if [[ $hour =~ ^[0-1]?[0-9]$|^2[0-3]$ ]]; then
            break
        else
            echo "Invalid hour. Please enter a number between 0 and 23."
        fi
    done

    # Get minute
    while true; do
        read -p "Enter the minute for reboot (0-59): " minute
        if [[ $minute =~ ^[0-5]?[0-9]$ ]]; then
            break
        else
            echo "Invalid minute. Please enter a number between 0 and 59."
        fi
    done

    # Create the schedule string and the comment
    if [[ $frequency == 1 ]]; then  # Monthly
        schedule="$minute $hour $day * *"
        comment="Monthly Reboot Task - Day: $day, Time: $hour:$minute"
    elif [[ $frequency == 2 ]]; then  # Weekly
        schedule="$minute $hour * * $day"
        comment="Weekly Reboot Task - Day of Week: $day, Time: $hour:$minute"
    else  # Daily
        schedule="$minute $hour * * *"
        comment="Daily Reboot Task - Time: $hour:$minute"
    fi

    # Add the comment and cron job
    echo "Adding cron job: $comment"
    (crontab -l 2>/dev/null; echo "# $comment"; echo "$schedule sudo shutdown -r now") | crontab -
    if [ $? -eq 0 ]; then
        echo "Reboot task added."
    else
        echo "Failed to add reboot task. Please check the input format."
    fi
}

# Function to list current reboot tasks in a human-readable format
list_reboot_tasks() {
    local header_footer_line=$(printf '%.0s#' {1..40}) # Adjust the number for width
    local task_separator_line=$(printf '%.0s-' {1..40}) # Adjust the number for width
    echo "$header_footer_line"
    local IFS=$'\n'
    local task_count=0
    local cron_lines=($(crontab -l))
    local total_tasks=$(grep -c '^#' <<< "${cron_lines[*]}")

    for line in "${cron_lines[@]}"; do
        if [[ "$line" == \#* ]]; then
            ((task_count++))
            [[ $task_count -gt 1 ]] && echo "$task_separator_line" # Separator between tasks
            echo "Task $task_count: ${line/#\# }"
        elif [ $task_count -gt 0 ]; then
            echo "Cron: $line"
        fi
    done

    if [ $task_count -eq 0 ]; then
        echo "No scheduled reboots found."
    fi
    echo "$header_footer_line"
}

# Function to delete a reboot task
delete_reboot_task() {
    echo "Select the task number to delete:"
    
    local IFS=$'\n'
    local task_count=0
    local cron_lines=($(crontab -l))
    local descriptions=()

    # Gather descriptions of tasks
    for line in "${cron_lines[@]}"; do
        if [[ "$line" == \#* ]]; then
            ((task_count++))
            descriptions+=("$task_count: ${line/#\# }")
        fi
    done

    # Display descriptions
    if [ ${#descriptions[@]} -eq 0 ]; then
        echo "No scheduled reboots found."
        return
    else
        for desc in "${descriptions[@]}"; do
            echo "$desc"
        done
    fi

    # Get user input
    local task_no
    read -p "Enter the task number: " task_no

    # Validate input
    if ! [[ "$task_no" =~ ^[0-9]+$ ]] || [ $task_no -lt 1 ] || [ $task_no -gt $task_count ]; then
        echo "Invalid input. Please enter a valid task number."
        return
    fi

    # Calculate the line number to delete (every task has 2 lines: comment and cron)
    local delete_line_no=$((2 * task_no))

    # Remove the task and its comment line
    crontab -l | sed -e "${delete_line_no}d; $((delete_line_no - 1))d" | crontab -
    echo "Reboot task deleted."
}

# Main script starts here

while true; do
    list_reboot_tasks
    echo "Choose an option:"
    echo "1. Add a new reboot task"
    echo "2. Delete an existing reboot task"
    echo "3. List all reboot tasks"
    echo "4. Exit"
    read -p "Enter your choice: " choice

    case $choice in
        1) 
            add_reboot_task
            ;;
        2) 
            delete_reboot_task
            ;;
        3) 
            # Listing is already done at the start of the loop, so just continue
            continue
            ;;
        4) 
            exit 0
            ;;
        *) 
            echo "Invalid option"; 
            ;;
    esac
done
