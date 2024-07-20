function fish_prompt
    if test "$TRANSIENT" = "1"
        set -g TRANSIENT 0
        # Clear from cursor to end of screen as `commandline -f repaint` does not do this
        # See https://github.com/fish-shell/fish-shell/issues/8418
        printf \e\[0J
        __starship_transient_prompt_func
    else if test -e $FISH_PROMPT_TEMP_FILE
        cat $FISH_PROMPT_TEMP_FILE
    else
        __starship_transient_prompt_func
    end
end

function fish_right_prompt
    if test "$RIGHT_TRANSIENT" = "1"
        set -g RIGHT_TRANSIENT 0
        __starship_transient_rprompt_func
    else if test -e $FISH_RIGHT_PROMPT_TEMP_FILE
        cat $FISH_RIGHT_PROMPT_TEMP_FILE
    else
        __starship_transient_rprompt_func
    end
end

function __starship_transient_prompt_func
    if type -q starship_transient_prompt_func
        starship_transient_prompt_func
    else
        printf "\e[1;32m❯\e[0m "
    end
end

function __starship_transient_rprompt_func
    if type -q starship_transient_rprompt_func
        starship_transient_rprompt_func
    else
        printf ""
    end
end

# Get the the temp directory to store async prompt
set -g ASYNC_PROMPT_TEMP_DIR (command mktemp -d)
set -g FISH_PROMPT_TEMP_FILE $ASYNC_PROMPT_TEMP_DIR'/'$fish_pid'_fish_prompt'
set -g FISH_RIGHT_PROMPT_TEMP_FILE $ASYNC_PROMPT_TEMP_DIR'/'$fish_pid'_fish_right_prompt'

# Set the async prompt signal
set -g ASYNC_PROMPT_SIGNAL SIGUSR1

# Generate prompt in other job
function __async_prompt_fire --on-event fish_prompt
    switch "$fish_key_bindings"
        case fish_hybrid_key_bindings fish_vi_key_bindings
            set STARSHIP_KEYMAP "$fish_bind_mode"
        case '*'
            set STARSHIP_KEYMAP insert
    end
    set STARSHIP_CMD_PIPESTATUS $pipestatus
    set STARSHIP_CMD_STATUS $status
    # Account for changes in variable name between v2.7 and v3.0
    set STARSHIP_DURATION "$CMD_DURATION$cmd_duration"
    set STARSHIP_JOBS (count (jobs -p))
    fish -c '
    ::STARSHIP:: prompt --terminal-width="'$COLUMNS'" --status='$STARSHIP_CMD_STATUS' --pipestatus="'$STARSHIP_CMD_PIPESTATUS'" --keymap='$STARSHIP_KEYMAP' --cmd-duration='$STARSHIP_DURATION' --jobs='$STARSHIP_JOBS' > '$FISH_PROMPT_TEMP_FILE'
    ::STARSHIP:: prompt --right --terminal-width="'$COLUMNS'" --status='$STARSHIP_CMD_STATUS' --pipestatus="'$STARSHIP_CMD_PIPESTATUS'" --keymap='$STARSHIP_KEYMAP' --cmd-duration='$STARSHIP_DURATION' --jobs='$STARSHIP_JOBS' > '$FISH_RIGHT_PROMPT_TEMP_FILE'
    kill -s "'$ASYNC_PROMPT_SIGNAL'" '$fish_pid &
    disown
end

# Repaint the prompt when ASYNC_PROMPT_SIGNAL received
function __async_prompt_repaint_prompt --on-signal "$ASYNC_PROMPT_SIGNAL"
    commandline -f repaint
end

# Remove the temp file to store async prompt when fish exit
function __async_prompt_cleanup --on-event fish_exit
    rm -f $FISH_PROMPT_TEMP_FILE
    rm -f $FISH_RIGHT_PROMPT_TEMP_FILE
end

# Disable virtualenv prompt, it breaks starship
set -g VIRTUAL_ENV_DISABLE_PROMPT 1

# Remove default mode prompt
builtin functions -e fish_mode_prompt

set -gx STARSHIP_SHELL "fish"

# Transience related functions
function reset-transient --on-event fish_postexec
    set -g TRANSIENT 0
    set -g RIGHT_TRANSIENT 0
end

function transient_execute
    if commandline --paging-mode
        commandline -f accept-autosuggestion
        return
    end
    commandline --is-valid
    if test $status != 2
        set -g TRANSIENT 1
        set -g RIGHT_TRANSIENT 1
        commandline -f repaint
    end
    commandline -f execute
end

# --user is the default, but listed anyway to make it explicit.
function enable_transience --description 'enable transient prompt keybindings'
    bind --user \r transient_execute
    bind --user -M insert \r transient_execute
end

# Erase the transient prompt related key bindings.
# --user is the default, but listed anyway to make it explicit.
# Erasing a user binding will revert to the preset.
function disable_transience --description 'remove transient prompt keybindings'
    bind --user -e \r
    bind --user -M insert -e \r
end

# Set up the session key that will be used to store logs
# We don't use `random [min] [max]` because it is unavailable in older versions of fish shell
set -gx STARSHIP_SESSION_KEY (string sub -s1 -l16 (random)(random)(random)(random)(random)0000000000000000)
