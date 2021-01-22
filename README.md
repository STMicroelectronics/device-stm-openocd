# stm32mp1-openocd #

This module is used to provide
* prebuilt OpenOCD executable for STM32MP1
* scripts for OpenOCD configuration for STM32MP1
* scripts to load and build Linux kernel source for STM32MP1

It is part of the STMicroelectronics delivery for Android (see the [delivery][] for more information).

[delivery]: https://wiki.st.com/stm32mpu/wiki/STM32MP15_distribution_for_Android_release_note_-_v2.0.0

## Description ##

This module version is the updated version for STM32MP15 distribution for Android V2.0
Please see the release notes for more details.

## Documentation ##

* The [release notes][] provide information on the release.
* The [distribution package][] provides detailed information on how to use this delivery.

[release notes]: https://wiki.st.com/stm32mpu/wiki/STM32MP15_distribution_for_Android_release_note_-_v2.0.0
[distribution package]: https://wiki.st.com/stm32mpu/wiki/STM32MP1_Distribution_Package_for_Android

## Dependencies ##

This module can't be used alone. It is part of the STMicroelectronics delivery for Android.

## Containing ##

This module contains several files and directories.

**prebuilt**
* `./prebuilt/openocd`: prebuilt executable of OpenOCD
* `./prebuilt/scripts/*`: configuration scripts for OpenOCD including ST-link

**source**
* `./source/load_openocd.sh`: script used to load OpenOCD source with required patches for STM32MP1
* `./source/build_openocd.sh`: script used to generate/update prebuilt images
* `./source/android_openocdbuild.config`: configuration file used by the build_openocd.sh script
* `./source/patch/*`: OpenOCD patches required (not yet up-streamed)

**stm32wrapper4dbg**
* A tool that adds a debug wrapper to a stm32 fsbl image (see details in associated [README.md](./stm32wrapper4dbg/README.md)).

## License ##

This module is distributed under the Apache License, Version 2.0 found in the [Apache-2.0](./LICENSES/Apache-2.0) file.

There are exceptions which are distributed under GPL License, Version 2.0 found in the [GPL-2.0](./LICENSES/GPL-2.0) file:
* all binaries provided in `./prebuilt/` directory
* all .patch files provided in `./source/patch/` directory
