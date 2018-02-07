//!
//! Copyright 2015 by Garmin Ltd. or its subsidiaries.
//! Subject to Garmin SDK License Agreement and Wearables
//! Application Developer Agreement.
//!

using Toybox.Ant as Ant;
using Toybox.System as System;
using Toybox.Time as Time;
using Toybox.Test as Test;

class BSXinsightSensor extends Ant.GenericChannel
{
	/**
	 * @brief Define a MO2 sensor
	 */
    const DEVICE_TYPE = 31;
    const PERIOD = 8192;

    /**
     * @brief BSX ANT+ manufacturer's ID
     */
    const ANT_BSX_MAN_ID = 0x0062;

    /**
     * @brief For testing invalid manufacturer ID
     *
     * @note Comment out the other value above.
     */
    //const ANT_BSX_MAN_ID = 0x1234;

	/**
	 * @brief Manifest constants for page 16 commands.
	 */
    const ANT_MO2_CMD_SET_TIME		= 0x00;
    const ANT_MO2_CMD_START_SESSION	= 0x01;
    const ANT_MO2_CMD_STOP_SESSION	= 0x02;
    const ANT_MO2_CMD_LAP			= 0x03;

    hidden var chanAssign;

    static const START_STOP_RETRIES = 30;
	hidden var mStartStopCount = 0;

	/**
	 * @brief The device must have 4KB of free memory to enable FIT file data recording.
	 */
	var supportsFIT = false;
    var data;
    var page_80;
    var page_81;
    var page_82;
    var searching;
    var searchStart;
    var gPrevEventCount;
    var deviceCfg;

    static const INSIGHT_STATE_UNKNOWN = 0;
    static const INSIGHT_STATE_STARTING = 1;
    static const INSIGHT_STATE_RUNNING = 2;
    static const INSIGHT_STATE_STOPPING = 3;
    static const INSIGHT_STATE_STOPPED = 4;

    var gDeviceState = INSIGHT_STATE_UNKNOWN;

	class MuscleOxygenDataPage {
	    static const PAGE_NUMBER = 1;
	    static const AMBIENT_LIGHT_HIGH = 0x3FE;
	    static const INVALID_HEMO = 0xFFF;
	    static const INVALID_HEMO_PERCENT = 0x3FF;

	    var eventCount;
	    var utcTimeSet;
	    var supportsAntFs;
	    var measurementInterval;
	    var totalHemoConcentration;
	    var previousHemoPercent;
	    var currentHemoPercent;
	    var isValid;

    	function initialize() {
	        eventCount = 0;
	        utcTimeSet = false;
	        supportsAntFs = false;
	        measurementInterval = 0;
	        totalHemoConcentration = 40.95;
	        previousHemoPercent = 102.3;
	        currentHemoPercent = 102.3;
	        isValid = false;
	    }

	    enum {
			INTERVAL_25 = 1,
			INTERVAL_50 = 2,
			INTERVAL_1 = 3,
			INTERVAL_2 = 4
		}

		function parse(payload) {
			eventCount = payload[1];
			utcTimeSet = (payload[2] & 0x01) != 0;
			supportsAntFs = (payload[3] & 0x01) != 0;
			measurementInterval = parseMeasureInterval(payload);
			totalHemoConcentration = ((payload[4] | ((payload[5] & 0x0F) << 8))) / 100f;
			previousHemoPercent = ((payload[5] >> 4) | ((payload[6] & 0x3F) << 4)) / 10f;
			currentHemoPercent = ((payload[6] >> 6) | (payload[7] << 2)) / 10f;

			/*
			 * Handle the state transitions for STARTING -> RUNNING and
			 * STOPPING -> STOPPED.
			 */
			isValid = (currentHemoPercent <= 100.0 && totalHemoConcentration <= 40.00);
		}

		hidden function parseMeasureInterval(payload) {
			var interval = payload[3] >> 1;
			var result = 0;
			if (INTERVAL_25 == interval) {
		    	result = .25;
			} else if (INTERVAL_50 == interval) {
		     	result = .50;
			} else if (INTERVAL_1 == interval) {
		     	result = 1;
			} else if (INTERVAL_2 == interval) {
		     	result = 2;
			}
			return result;
		}
	}

	/*
	 * Large devices only.

	class ManufacturerDataPage {
	    static const PAGE_NUMBER = 0x50;

	    var hwRevision;
	    var manufacturer;
	    var model;

	    function initialize() {
	    	hwRevision = 0;
	    	manufacturer = 0;
	    	model = 0;
	    }

		function parse(payload) {
			if (payload[0] & 0xFF != PAGE_NUMBER) {
				return;
			}
			hwRevision = payload[3] & 0xFF;
			manufacturer = ((payload[4] & 0xFF) | ((payload[5] & 0xFF) << 8));
			model = ((payload[6] & 0xFF) | ((payload[7] & 0xFF) << 8));
		}
	}

	class ProductInfoPage {
	    static const PAGE_NUMBER = 0x51;

	    var swRevision;
	    var serial;

	    function initialize() {
	    	swRevision = 0;
	    	serial = 0;
	    }

		function parse(payload) {
			if (payload[0] & 0xFF != PAGE_NUMBER) {
				return;
			}
			if (payload[2] & 0xFF == 0xFF) {
				swRevision = 0;
			} else {
				swRevision = payload[2] & 0xFF;
			}
			if (payload[3] & 0xFF != 0xFF) {
				swRevision += (payload[3] & 0xFF) * 1000;
			}
			serial = ((payload[4] & 0xFF) | ((payload[5] & 0xFF) << 8) | ((payload[6] & 0xFF) << 16) | ((payload[7] & 0xFF) << 24));
		}
	}

	class BatteryPage {
	    static const PAGE_NUMBER = 0x52;

	    static const ANT_COMMON_BAT_NEW			= 0x01;
	    static const ANT_COMMON_BAT_GOOD		= 0x02;
	    static const ANT_COMMON_BAT_OK			= 0x03;
	    static const ANT_COMMON_BAT_LOW			= 0x04;
	    static const ANT_COMMON_BAT_CRITICAL	= 0x05;

	    var level;

	    function initialize() {
	    	level = ANT_COMMON_BAT_OK;
	    }

		function parse(payload) {
			if (payload[0] & 0xFF != PAGE_NUMBER) {
				return;
			}
			level = (payload[7] >> 4) & 0x07;
		}
	}

	 */

	class CommandDataPage {
		static const PAGE_NUMBER = 0x10;
	}

    function initialize() {

        /*
         * Some devices support FIT files, some don't. The determination is made
         * here because this object is passed around, so the check can be made in
         * variety of places.
         */
        if (System.getSystemStats().freeMemory >= (4*1024)) {
        	supportsFIT = true;
        }

        // Get the channel
        chanAssign = new Ant.ChannelAssignment(
            Ant.CHANNEL_TYPE_RX_NOT_TX,
            Ant.NETWORK_PLUS);
        GenericChannel.initialize(method(:onMessage), chanAssign);

        // Set the configuration
		// The first configuration we set has a high priority timeout in it.
		// We do that in order to try to find a device as quickly as possible.
        deviceCfg = new Ant.DeviceConfig({
            :deviceNumber => 0,                 //Wildcard our search
            :deviceType => DEVICE_TYPE,			// MO2 Sensor
            :transmissionType => 0,
            :messagePeriod => PERIOD,
            :radioFrequency => 57,				//ANT+ Frequency
            :searchTimeoutLowPriority => 10,	//Timeout in 50s
            :searchTimeoutHighPriority => 0,	//Timeout in 0s
            :searchThreshold => 0});			//Pair to all transmitting sensors

        setDeviceConfig(deviceCfg);

        data = new MuscleOxygenDataPage();

        searching = true;
        searchStart = Time.now().value();
    }

    function open() {
        // Open the channel
        if (GenericChannel.open()) {
	        data = new MuscleOxygenDataPage();
    	    gPrevEventCount = 0;
        	searching = true;
        	searchStart = Time.now().value();
        }
    }

    function closeSensor() {
        GenericChannel.close();
        data = null;
    }


	/**
	 * @brief Send an ANT+ command to the BSXinsight
	 */
	function commonSendMessage(messageType) {
        //Create and populat the data payload
        var payload = new[8];
        payload[0] = CommandDataPage.PAGE_NUMBER;
        payload[1] = messageType;
        payload[2] = 0xFF; //Reserved

		var curClockTime = System.getClockTime();
        payload[3] = curClockTime.timeZoneOffset / (15*60); //Signed 2's complement value indicating local time offset in 15m intervals

        /*
         * Transmit the current device time in little-endian order.
         */
        var moment = Time.now().value();
        for(var i = 0; i < 4; i++) {
            payload[i + 4] = (moment & 0xFF);
            moment = moment >> 8;
        }

        //Form and send the message
        var message = new Ant.Message();
        message.setPayload(payload);
        GenericChannel.sendAcknowledge(message);

        message = null;
        payload = null;
	}

    function setTime() {
        if (! searching && (data.utcTimeSet)) {
			commonSendMessage(ANT_MO2_CMD_SET_TIME);
        }
    }

 	function startActivity() {
		if (page_80 != null && page_80.manufacturer != 0 && page_80.manufacturer != ANT_BSX_MAN_ID) {
			return;
		}
 		if (gDeviceState == INSIGHT_STATE_RUNNING) {
 			return;
 		}
        if (! searching) {
        	if (gDeviceState == INSIGHT_STATE_STARTING) {
	        	mStartStopCount++;
	        	if (mStartStopCount > START_STOP_RETRIES) {
	        		gDeviceState = INSIGHT_STATE_RUNNING;
	        		return;
	        	}
	        } else {
				gDeviceState = INSIGHT_STATE_STARTING;
	        	mStartStopCount = 0;
	        }
            commonSendMessage(ANT_MO2_CMD_START_SESSION);
        }
    }

    function stopActivity() {
        if (! searching) {
        	if (gDeviceState == INSIGHT_STATE_STOPPING) {
        		mStartStopCount++;
	        	if (mStartStopCount > START_STOP_RETRIES) {
	        		gDeviceState = INSIGHT_STATE_STOPPED;
	        		return;
	        	}
        	} else {
				gDeviceState = INSIGHT_STATE_STOPPING;
	        	mStartStopCount = 0;
	        }
            commonSendMessage(ANT_MO2_CMD_STOP_SESSION);
        }
    }

    function onMessage(msg) {
        // Parse the payload
        var payload = msg.getPayload();

        if (Ant.MSG_ID_BROADCAST_DATA == msg.messageId) {
            if (MuscleOxygenDataPage.PAGE_NUMBER == (payload[0].toNumber() & 0xFF)) {
                // Were we searching?
                if (searching) {
                    searching = false;
            		// DEBUG
            		//System.println("Device Found.");

                    // Update our device configuration primarily to see the device number of the sensor we paired to
                    deviceCfg = GenericChannel.getDeviceConfig();
                }

                data.parse(msg.getPayload());
				if (gDeviceState == INSIGHT_STATE_STARTING && data.isValid) {
					gDeviceState = INSIGHT_STATE_RUNNING;
				} else if (gDeviceState == INSIGHT_STATE_STOPPING && ! data.isValid) {
					gDeviceState = INSIGHT_STATE_STOPPED;
				}

                // Check if the data has changed
                if (gPrevEventCount != data.eventCount) {
                    gPrevEventCount = data.eventCount;
                    if (data.utcTimeSet == true) {
                    	setTime();
                    }
                }
            /*
             * Large devices only.

            } else if (supportsFIT && ManufacturerDataPage.PAGE_NUMBER == (payload[0].toNumber() & 0xFF)) {
            	if (page_80 == null) {
            		page_80 = new ManufacturerDataPage();
				}
            	page_80.parse(payload);
            	// DEBUG
            	//System.println("manufacturer = " + page_80.manufacturer + ", H/W rev = " + page_80.hwRevision + ", model = " + page_80.model);
            } else if (supportsFIT && ProductInfoPage.PAGE_NUMBER == (payload[0].toNumber() & 0xFF)) {
            	if (page_81 == null) {
            		page_81 = new ProductInfoPage();
            	}
            	page_81.parse(payload);
            	// DEBUG
            	//System.println("swRevision = " + page_81.swRevision + ", serial = " + page_81.serial.format("%08x"));
            } else if (supportsFIT && BatteryPage.PAGE_NUMBER == (payload[0].toNumber() & 0xFF)) {
            	if (page_82 == null) {
            		page_82 = new BatteryPage();
            	}
            	page_82.parse(payload);
            	// DEBUG
            	//System.println("battery level = " + page_82.level);
           	*/
            } else {
            	// DEBUG
            	//System.println("page " + payload[0].toNumber() & 0xFF);
            }
        } else if (Ant.MSG_ID_CHANNEL_RESPONSE_EVENT == msg.messageId) {
            if (Ant.MSG_ID_RF_EVENT == (payload[0] & 0xFF)) {
                if (Ant.MSG_CODE_EVENT_CHANNEL_CLOSED == (payload[1] & 0xFF)) {
                    open();
                } else if (Ant.MSG_CODE_EVENT_RX_FAIL_GO_TO_SEARCH  == (payload[1] & 0xFF)) {
                    searching = true;
                }
            } else {
                //It is a channel response.
            }
        }
	}
}