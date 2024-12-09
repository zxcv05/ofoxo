# ofoxo
fox follow mouse (real)

# Dependencies
- (dev) Zig v0.13.0
- OpenGL 4.4
- GLFW

# Build
`$ zig build`

# Run
`$ zig build run`

# Install
`# zig build --prefix /usr/`

# Troubleshooting
- When building under windows, if you get a TlsInitializationError, you probably have a broken zig installation. Try using winget
- If ofoxo makes all of your monitors blurry, add an x11 class rule for "ofoxo" to disable any effects
- If ofoxo fails to run with "OpenGL failure: invalid operation", try building with ReleaseSmall or ReleaseFast

# Contributing
No special steps. Happy hacking!
