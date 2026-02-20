function log
    set_color cyan; echo ":: $argv"; set_color normal
end

function warn
    set_color yellow; echo ":: $argv"; set_color normal
end

function err
    set_color red; echo ":: $argv"; set_color normal
end

function success
    set_color green; echo ":: $argv"; set_color normal
end
