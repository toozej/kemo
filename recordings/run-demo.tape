# Kemo Run Demo Example
# Shows running the hello-world demo with the good variant

Output recordings/run-demo.gif

Set Shell "bash"
Set Theme "Dracula"
Set Width 1200
Set Height 800
Set FontSize 14
Set Padding 20

# Run the hello-world demo with good variant
Type "just run-demo hello-world good"
Enter

# Wait for Kubernetes setup and demo to start
Sleep 10s

# Show the tmux interface for a moment
Sleep 5s

# The demo will launch tmux - capture the interface
Sleep 3s
