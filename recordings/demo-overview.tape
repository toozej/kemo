# Kemo Demo Overview
# Demonstrates available commands and environment health check

Output recordings/demo-overview.gif

Set Shell "bash"
Set Theme "Dracula"
Set Width 1200
Set Height 600
Set FontSize 14
Set Padding 20

# Show available commands
Type "just --list"
Enter
Sleep 3s

# Run health check
Type "just health-check"
Enter
Sleep 4s

# Browse demos (brief glimpse)
Type "just browse-demos"
Enter
Sleep 3s

# Exit the demo browser
Ctrl+C
Sleep 1s
