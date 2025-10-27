# Resources Directory

This directory contains app resources like sounds and images.

## Required Files

### chime.aiff
A custom chime sound file for one-minute meeting warnings.

To add the chime sound:
1. Find or create a short (1-2 second) pleasant chime sound
2. Convert it to AIFF format
3. Name it `chime.aiff`
4. Place it in this directory
5. Add it to the Xcode project target

Alternatively, you can use the system default sound by modifying NotificationManager to use:
```swift
content.sound = .default
```
