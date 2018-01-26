# BSX Insight ConnectIQ Data Field Application

This repository contains the source code for the BSX Insight data field application which is
available from the
[Garmin connect IQ](https://apps.garmin.com/en-US/apps/3e33449b-db56-40d3-b512-b74bfe78e9ee)
app store. This repository includes both the source code and Eclipse `.project` file,
located in the `BSXField` directory, and the assets and compiled binaries for the app
store, located in the `BSXField_exports` directory.

## `BSXField` Directory

This directory contains the required Eclipse `.project` file needed to perform development
on the `BSXField` app, as well as the associated source code. A developer will need to
import this subdirectory as a project in order to use the Connect IQ toolchain and project
type features. 

The contents of this directory will be published as an Open Source Software (OSS) project
under a BSD license. Any update to this directory must be cleansed of historical changes
prior to being committed back to that other repository.

You will need to modify the `manifest.xml` to reflect your devices. You may also select
a device using the `Connect IQ` Eclipse menu "Build For Device Wizard..."

## `BSXField_export` Directory

This directory contains the assets -- images and compiled binaries -- required by the Garmin
app store web page.

The contents of this directory must not be included when this app is released as an OSS
project.

## `images` Directory

This directory contains example screen shots which show the regular behavior of the application
on a Garmin Edge 520 cycling computer.
