# OpenJDK (Homebrew, keg-only)
# Activated from conf.d/ so JAVA_HOME and PATH are set for every shell
set -l brew_openjdk /opt/homebrew/opt/openjdk@21
if test -d $brew_openjdk
    set -gx JAVA_HOME $brew_openjdk/libexec/openjdk.jdk/Contents/Home
    fish_add_path $brew_openjdk/bin
end
