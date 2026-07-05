# Non-interactive Tide configuration for the screenshot-inspired prompt.

set -U tide_prompt_add_newline_before false
set -U tide_prompt_color_frame_and_connection brblack
set -U tide_prompt_color_separator_same_color brblack
set -U tide_prompt_color_separator_diff_color brblack
set -U tide_prompt_icon_connection '─'
set -U tide_prompt_min_cols 34
set -U tide_prompt_pad_items true
set -U tide_prompt_transient_enabled false

set -U tide_left_prompt_frame_enabled true
set -U tide_right_prompt_frame_enabled false
set -U tide_left_prompt_prefix ''
set -U tide_left_prompt_suffix ''
set -U tide_right_prompt_prefix ''
set -U tide_right_prompt_suffix ''
set -U tide_left_prompt_separator_same_color '│'
set -U tide_right_prompt_separator_same_color '│'
set -U tide_left_prompt_separator_diff_color ''
set -U tide_right_prompt_separator_diff_color ''

set -U tide_left_prompt_items os pwd newline character
set -U tide_right_prompt_items context time
set -U _tide_left_items os pwd newline character
set -U _tide_right_items context time

if functions -q _tide_detect_os
    _tide_detect_os | read -l --line os_icon os_color os_bg_color
    set -U tide_os_icon "$os_icon"
else
    set -U tide_os_icon ''
end
set -U tide_os_color E4E4E4
set -U tide_os_bg_color 1C1C1C

set -U tide_pwd_bg_color 1C1C1C
set -U tide_pwd_color_anchors 00AFFF
set -U tide_pwd_color_dirs 0087AF
set -U tide_pwd_color_truncated_dirs 8787AF
set -U tide_pwd_icon ''
set -U tide_pwd_icon_home ''
set -U tide_pwd_icon_unwritable ''
set -U tide_pwd_markers .git

set -U tide_character_icon '❯'
set -U tide_character_color 5FD700
set -U tide_character_color_failure red
set -U tide_character_vi_icon_default '❯'
set -U tide_character_vi_icon_replace '▶'
set -U tide_character_vi_icon_visual 'V'

set -U tide_context_always_display true
set -U tide_context_bg_color 1C1C1C
set -U tide_context_color_default D7AF87
set -U tide_context_color_root red
set -U tide_context_color_ssh D7AF87
set -U tide_context_hostname_parts 1

set -U tide_time_bg_color 1C1C1C
set -U tide_time_color 5F8787
set -U tide_time_format '%I:%M:%S %p'

set -U tide_cmd_duration_bg_color black
set -U tide_cmd_duration_color yellow
set -U tide_cmd_duration_decimals 0
set -U tide_cmd_duration_icon '󰔟'
set -U tide_cmd_duration_threshold 3000

set -U tide_status_bg_color black
set -U tide_status_bg_color_failure black
set -U tide_status_color 5FD700
set -U tide_status_color_failure red
set -U tide_status_icon '✔'
set -U tide_status_icon_failure '✘'

set -U tide_git_bg_color black
set -U tide_git_bg_color_unstable black
set -U tide_git_bg_color_urgent black
set -U tide_git_color_branch white
set -U tide_git_color_conflicted red
set -U tide_git_color_dirty yellow
set -U tide_git_color_operation red
set -U tide_git_color_staged 5FD700
set -U tide_git_color_stash 5F8787
set -U tide_git_color_untracked 5F8787
set -U tide_git_color_upstream 5F8787
set -U tide_git_icon ''
set -U tide_git_truncation_length 24
set -U tide_git_truncation_strategy ''
