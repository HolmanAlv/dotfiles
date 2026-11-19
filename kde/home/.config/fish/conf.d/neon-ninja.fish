# Only inside the Neon Ninja kitty: every other terminal keeps its setup
if set -q NEON_NINJA
    # ANSI colors, so these tools follow the terminal's palette
    set -gx FZF_DEFAULT_OPTS "$FZF_DEFAULT_OPTS --color=16"
    set -gx BAT_THEME ansi

    function btop --wraps btop --description 'btop with the Neon Ninja theme'
        command btop --config ~/.config/btop/neon-ninja.conf $argv
    end
end
