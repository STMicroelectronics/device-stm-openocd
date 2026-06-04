# stm32mp2-openocd #

This module is used to provide
* prebuilt OpenOCD executable for STM32MP2
* scripts for OpenOCD configuration for STM32MP2
* scripts to load and build OpenOCD source for STM32MP2

It is part of the STMicroelectronics delivery for Android.

## Description ##

This module targets STM32MP25 in OpenSTDroid v6.2.0.
Please see the release notes for more details.

## Documentation ##

* The [release notes][] provide information on the release.
[release notes]: https://wiki.st.com/stm32mpu/wiki/STM32_MPU_OpenSTDroid_release_note_-_v6.2.0

## Dependencies ##

This module cannot be used alone. It is part of the STMicroelectronics delivery for Android.

## Contents ##

This module contains several files and directories.

**Prebuilt**
* `./prebuilt/openocd`: prebuilt executable of OpenOCD
* `./prebuilt/scripts/*`: configuration scripts for OpenOCD including ST-link

**Source**
* `./source/load_openocd.sh`: script used to load OpenOCD source with required patches for STM32MP2
* `./source/build_openocd.sh`: script used to generate/update prebuilt images
* `./source/android_openocdbuild.config`: configuration file used by the build_openocd.sh script
* `./source/patch/*`: OpenOCD patches required (not yet upstreamed)

**stm32wrapper4dbg**
* A tool that adds a debug wrapper to a STM32 fsbl image (see details in associated [README.md](./stm32wrapper4dbg/README.md)).

## License ##

This module is distributed under the Apache License, Version 2.0 found in the [Apache-2.0](./LICENSES/Apache-2.0) file.

There are exceptions which are distributed under GPL License, Version 2.0 found in the [GPL-2.0](./LICENSES/GPL-2.0) file:
* all binaries provided in `./prebuilt/` directory
* all .patch files provided in `./source/patch/` directory
