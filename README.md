# Beeper for Ubuntu Touch
This projects downloads the latest AppImage of the Beeper desktop client, patches it and packages it up as a clickable for Ubuntu Touch

I can't publish this on the OpenStore since the Beeper client isn't FOSS.

## Download
You can download a pre-built click file from the [Releases](https://github.com/nimafanniasl/uBeeper/releases/latest) page.

## Build Instructions
1. [Install Clickable](https://clickable-ut.dev/en/latest/install.html)
2. `clickable build --arch arm64 --skip-review`
3. `clickable install && clickable launch`

## Known Issues
- It's a bit laggy
- Digital Keyboard doesn't show up automatically
- The UI doesn't get scaled properly (Global Issue for now on UT)

## Credits
- Patches from the [beeper-v4-bin](https://aur.archlinux.org/packages/beeper-v4-bin) package in the AUR
- [vscodium-click-packaging](https://github.com/fredldotme/vscodium-click-packaging/)