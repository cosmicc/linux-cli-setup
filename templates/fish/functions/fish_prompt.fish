# linux-cli-setup managed Tide prompt.
#
# Keep this aligned with the reference prompt screenshot: OS and current
# directory on the left, a horizontal frame, context and time on the right,
# and the prompt character on the second line.

function fish_prompt
    _tide_status=$status _tide_pipestatus=$pipestatus if not set -e _tide_repaint
        jobs -q && jobs -p | count | read -lx _tide_jobs
        /usr/bin/fish -c "set _tide_pipestatus $_tide_pipestatus
set _tide_parent_dirs $_tide_parent_dirs
PATH=$(string escape "$PATH") CMD_DURATION=$CMD_DURATION fish_bind_mode=$fish_bind_mode set _tide_prompt_3628818 (_tide_2_line_prompt)" &
        builtin disown

        command kill $_tide_last_pid 2>/dev/null
        set -g _tide_last_pid $last_pid
    end

    math $COLUMNS-(string length -V "$_tide_prompt_3628818[1]$_tide_prompt_3628818[3]")+3 | read -lx dist_btwn_sides

    echo -ns \n'╭─'(string replace @PWD@ (_tide_pwd) "$_tide_prompt_3628818[1]")''
    string repeat -Nm(math max 0, $dist_btwn_sides-$_tide_pwd_len) '─'
    echo -ns "$_tide_prompt_3628818[3]"\n"╰─$_tide_prompt_3628818[2] "
end
