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

set -U tide_left_prompt_items os pwd git newline character
set -U tide_right_prompt_items status cmd_duration context jobs direnv bun node python rustc java php pulumi ruby go gcloud kubectl distrobox toolbox terraform aws nix_shell crystal elixir zig time
set -U _tide_left_items os pwd git newline character
set -U _tide_right_items status cmd_duration context jobs direnv bun node python rustc java php pulumi ruby go gcloud kubectl distrobox toolbox terraform aws nix_shell crystal elixir zig time

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
set -U tide_pwd_markers .bzr .citc .git .hg .node-version .python-version .ruby-version .shorten_folder_marker .svn .terraform bun.lockb Cargo.toml composer.json CVS go.mod package.json build.zig

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

set -U tide_cmd_duration_bg_color 1C1C1C
set -U tide_cmd_duration_color 87875F
set -U tide_cmd_duration_decimals 0
set -U tide_cmd_duration_icon '󰔟'
set -U tide_cmd_duration_threshold 3000

set -U tide_status_bg_color 1C1C1C
set -U tide_status_bg_color_failure 1C1C1C
set -U tide_status_color 5FD700
set -U tide_status_color_failure red
set -U tide_status_icon '✔'
set -U tide_status_icon_failure '✘'

set -U tide_git_bg_color 1C1C1C
set -U tide_git_bg_color_unstable 1C1C1C
set -U tide_git_bg_color_urgent 1C1C1C
set -U tide_git_color_branch 5FD700
set -U tide_git_color_conflicted FF0000
set -U tide_git_color_dirty D7AF00
set -U tide_git_color_operation FF0000
set -U tide_git_color_staged D7AF00
set -U tide_git_color_stash 5F8787
set -U tide_git_color_untracked 00AFFF
set -U tide_git_color_upstream 5FD700
set -U tide_git_icon ''
set -U tide_git_truncation_length 24
set -U tide_git_truncation_strategy ''

set -U tide_jobs_bg_color 1C1C1C
set -U tide_jobs_color 5F8700
set -U tide_jobs_icon ''
set -U tide_jobs_number_threshold 1000

set -U tide_direnv_bg_color 1C1C1C
set -U tide_direnv_bg_color_denied 1C1C1C
set -U tide_direnv_color D7AF00
set -U tide_direnv_color_denied FF0000
set -U tide_direnv_icon '▼'

set -U tide_bun_bg_color 1C1C1C
set -U tide_bun_color FBF0DF
set -U tide_bun_icon '󰳓'

set -U tide_node_bg_color 1C1C1C
set -U tide_node_color 44883E
set -U tide_node_icon ''

set -U tide_python_bg_color 1C1C1C
set -U tide_python_color 00AFAF
set -U tide_python_icon '󰌠'

set -U tide_rustc_bg_color 1C1C1C
set -U tide_rustc_color F74C00
set -U tide_rustc_icon ''

set -U tide_java_bg_color 1C1C1C
set -U tide_java_color ED8B00
set -U tide_java_icon ''

set -U tide_php_bg_color 1C1C1C
set -U tide_php_color 617CBE
set -U tide_php_icon ''

set -U tide_pulumi_bg_color 1C1C1C
set -U tide_pulumi_color F7BF2A
set -U tide_pulumi_icon ''

set -U tide_ruby_bg_color 1C1C1C
set -U tide_ruby_color B31209
set -U tide_ruby_icon ''

set -U tide_go_bg_color 1C1C1C
set -U tide_go_color 00ACD7
set -U tide_go_icon ''

set -U tide_gcloud_bg_color 1C1C1C
set -U tide_gcloud_color 4285F4
set -U tide_gcloud_icon '󰊭'

set -U tide_kubectl_bg_color 1C1C1C
set -U tide_kubectl_color 326CE5
set -U tide_kubectl_icon '󱃾'

set -U tide_distrobox_bg_color 1C1C1C
set -U tide_distrobox_color FF00FF
set -U tide_distrobox_icon '󰆧'

set -U tide_toolbox_bg_color 1C1C1C
set -U tide_toolbox_color 613583
set -U tide_toolbox_icon ''

set -U tide_terraform_bg_color 1C1C1C
set -U tide_terraform_color 844FBA
set -U tide_terraform_icon '󱁢'

set -U tide_aws_bg_color 1C1C1C
set -U tide_aws_color FF9900
set -U tide_aws_icon ''

set -U tide_nix_shell_bg_color 1C1C1C
set -U tide_nix_shell_color 7EBAE4
set -U tide_nix_shell_icon ''

set -U tide_crystal_bg_color 1C1C1C
set -U tide_crystal_color FFFFFF
set -U tide_crystal_icon ''

set -U tide_elixir_bg_color 1C1C1C
set -U tide_elixir_color 4E2A8E
set -U tide_elixir_icon ''

set -U tide_zig_bg_color 1C1C1C
set -U tide_zig_color F7A41D
set -U tide_zig_icon ''
