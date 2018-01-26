## Version 2.0.0

This version marks the first open source release of the BSXinsight Garmin app. This project was verified using SDK 2.4.1
on a Garmin Edge 520.

The following changes have been made --

 * Improved startup and error screens.
   * "Waiting", "Starting", and "Reconnecting" screens indicate device status.
 * BSXinsight activity is no started until Garmin activity is started.
   * Activity is started and stopped on the BSXinsight as the activity on the Garmin device
     is started, paused, resumed, and stopped.
 * tHB and smO2 data is added to the activity `.fit` file.
 * Example screen shots are included in the [images](images) folder.
