# Non-interactive Tide configuration for the screenshot-inspired prompt.

set -U tide_prompt_add_newline_before false
set -U tide_prompt_color_frame_and_connection brblack
set -U tide_prompt_color_separator_same_color brblack
set -U tide_prompt_color_separator_diff_color brblack
set -U tide_prompt_icon_connection ' '
set -U tide_prompt_min_cols 34

set -U tide_left_prompt_items os pwd newline character
set -U tide_right_prompt_items context time

set -U tide_os_bg_color black
set -U tide_os_color white

set -U tide_pwd_bg_color black
set -U tide_pwd_color_anchors brblue
set -U tide_pwd_color_dirs brblue
set -U tide_pwd_color_truncated_dirs brblack
set -U tide_pwd_icon ''
set -U tide_pwd_icon_home ''
set -U tide_pwd_markers .git

set -U tide_character_icon '❯'
set -U tide_character_color brgreen
set -U tide_character_color_failure brred
set -U tide_character_vi_icon_default '❮'
set -U tide_character_vi_icon_replace '▶'
set -U tide_character_vi_icon_visual 'V'

set -U tide_context_always_display true
set -U tide_context_bg_color black
set -U tide_context_color_default brwhite
set -U tide_context_color_root brred

set -U tide_time_bg_color black
set -U tide_time_color brcyan
set -U tide_time_format '%I:%M:%S %p'

set -U tide_cmd_duration_bg_color black
set -U tide_cmd_duration_color yellow
set -U tide_status_bg_color black
set -U tide_status_bg_color_failure black
set -U tide_status_color brgreen
set -U tide_status_color_failure brred

set -U tide_git_bg_color black
set -U tide_git_bg_color_unstable black
set -U tide_git_bg_color_urgent black
set -U tide_git_color_branch brwhite
set -U tide_git_color_conflicted brred
set -U tide_git_color_dirty yellow
set -U tide_git_color_operation brred
set -U tide_git_color_staged brgreen
set -U tide_git_color_stash brcyan
set -U tide_git_color_untracked brcyan
set -U tide_git_color_upstream brcyan
