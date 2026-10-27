function flatten_commandline --description 'Join a multi-line command line into one line'
    commandline --replace -- (string join ' ' (commandline | string trim | string match --invert ''))
end
