using Toybox.WatchUi as Ui;
using Toybox.Application as App;
using Toybox.System as Sys;
using Toybox.Time as Time;
using Toybox.Activity as Act;
using Toybox.Graphics as Gfx;

/**
 * @note This datafield application must be compiled with SDK 2.4.2 or more recent.
 */

const BORDER_PAD = 4;
const UNITS_SPACING = 2;

const START_RETRIES = 30;
const STOP_RETRIES = 30;
const STOP_ON_EXIT_RETRIES = 30;

const BSX_ORANGE = 0xff8400;

class MO2Field extends Ui.DataField
{
    //Label Variables
    hidden var mLabelString = "BSXinsight";
    hidden var mLabelFont = Gfx.FONT_TINY;

    //Hemoglobin Concentration variables
	hidden var mHCUnitsString = "tHb";
    hidden var mHCUnitsWidth;
    hidden var mHCX;
    hidden var mHCY;

    //Hemoglobin Percentage variables
    hidden var mHPUnitsString = "%";
    hidden var mHPUnitsWidth;
    hidden var mHPX;
    hidden var mHPY;

    // Fit Contributor
    hidden var mFitContributor;

    //Font values
    hidden var mDataFont;
    hidden var mDataFontAscent;
    hidden var mUnitsFont = Gfx.FONT_TINY;

    //field separator line
    hidden var separator;

    hidden var bsxSensor;
    hidden var xCenter;
    hidden var yCenter;

    hidden var startStopCounter;
    hidden var lastTimerTime = 0;

    //! Constructor
    function initialize(sensor) {
    	DataField.initialize();

		bsxSensor = sensor;
		if (bsxSensor.supportsFIT) {
	        mFitContributor = new MO2FitContributor(self);
		}
        startStopCounter = 0;
    }

    function compute(info) {
		if (bsxSensor.searching) {
			return;
		}

    	/*
    	 * Log FIT file data if running and the feature is enabled.
    	 */
    	if (info != null && bsxSensor.gDeviceState == BSXinsightSensor.INSIGHT_STATE_RUNNING && mFitContributor != null) {
	        mFitContributor.compute(bsxSensor);
	    }

    	if (info != null && info.startTime != null) {
    		var newActivity = lastTimerTime > info.timerTime;
    		var stoppedActivity = lastTimerTime == info.timerTime;

    		lastTimerTime = info.timerTime;

       		/*
       		 * There is a start time, which means there is an activity.
       		 */
       		if (bsxSensor.gDeviceState == BSXinsightSensor.INSIGHT_STATE_UNKNOWN && ! stoppedActivity &&
       				((! (info has :timerState)) || info.timerState == Act.TIMER_STATE_ON)) {
       			// DEBUG
       			//System.println("start tardy device");

       			/*
       			 * The head unit thinks it started an activity, but the Insight hasn't been
       			 * started or anything.
       			 */
				bsxSensor.startActivity();
       		} else if (bsxSensor.gDeviceState == BSXinsightSensor.INSIGHT_STATE_STOPPED && newActivity) {
       			if (bsxSensor.page_80 == null || (bsxSensor.page_80.manufacturer != 0 &&
       					bsxSensor.page_80.manufacturer == bsxSensor.ANT_BSX_MAN_ID)) {
       				// DEBUG
       				//System.println("restart stopped device");

       				/*
       				 * This app thinks the Insight should be stopped, but the head unit
       				 * thinks it should be running.
       				 */
        			bsxSensor.startActivity();
       			}
       		}
       	} else {
       		/*
       		 * There is no start time at all, so there is no activity.
       		 */
       		if (bsxSensor.gDeviceState != BSXinsightSensor.INSIGHT_STATE_STOPPED) {
       			// DEBUG
       			//System.println("stop runaway device");

				bsxSensor.stopActivity();
       		}
       	}

       	if (bsxSensor.gDeviceState != BSXinsightSensor.INSIGHT_STATE_UNKNOWN) {
			if (bsxSensor.gDeviceState == BSXinsightSensor.INSIGHT_STATE_STARTING) {
				// DEBUG
				//System.println("start activity");

				/*
				 * The "start activity" command will be sent until valid data is
				 * received or the counter runs out.
				 */
				bsxSensor.startActivity();
			} else if (bsxSensor.gDeviceState == BSXinsightSensor.INSIGHT_STATE_STOPPING) {
				// DEBUG
				//System.println("stop activity");

				/*
				 * The "stop activity" command will be sent until invalid data is
				 * received or the counter runs out.
				 */
				bsxSensor.stopActivity();
			} else if (bsxSensor.gDeviceState == BSXinsightSensor.INSIGHT_STATE_STOPPED) {
				if (bsxSensor.data.isValid) {
					// DEBUG
					//System.println("zombie device came back to life");

					bsxSensor.stopActivity();
				}
			}
		}
    }

    function onLayout(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();

		var top = BORDER_PAD;

        var vLayoutWidth;
        var vLayoutHeight;
        var vLayoutFontId;

        var hLayoutWidth;
        var hLayoutHeight;
        var hLayoutFontId;

        //Units width does not change, compute only once
        if (mHCUnitsWidth == null) {
            mHCUnitsWidth = dc.getTextWidthInPixels(mHCUnitsString, mUnitsFont) + UNITS_SPACING;
        }
        if (mHPUnitsWidth == null) {
            mHPUnitsWidth = dc.getTextWidthInPixels(mHPUnitsString, mUnitsFont) + UNITS_SPACING;
        }

        //Compute data width/height for both layouts
        hLayoutWidth = (width - (4 * BORDER_PAD)) / 2;
        hLayoutHeight = height - (4 * BORDER_PAD) - top;
        hLayoutFontId = selectDataFont(dc, (hLayoutWidth - mHCUnitsWidth), hLayoutHeight - (hLayoutHeight / 8));

        vLayoutWidth = width - (2 * BORDER_PAD);
        vLayoutHeight = (height - top - (4 * BORDER_PAD)) / 2;
        vLayoutFontId = selectDataFont(dc, (vLayoutWidth - mHCUnitsWidth), vLayoutHeight-(vLayoutHeight/8));

        //Use the horizontal layout if it supports a larger font
        if (hLayoutFontId > vLayoutFontId) {
            mDataFont = hLayoutFontId;
            mDataFontAscent = Gfx.getFontAscent(mDataFont);

 			//Compute the center of the Hemo Percentage data
            mHPX = BORDER_PAD + (hLayoutWidth / 2) + (hLayoutWidth / 8) - (mHPUnitsWidth  / 2);
            mHPY = (height - top) / 2 + top - (mDataFontAscent / 2);

            //Compute the draw location of the Hemoglobin Concentration data
            mHCX = (2 * BORDER_PAD) + hLayoutWidth + (hLayoutWidth / 2) - (hLayoutWidth / 16) - (mHCUnitsWidth / 2);
            mHCY = (height - top) / 2 + top - (mDataFontAscent / 2);

            //Use a separator line for horizontal layout
            separator = [(width / 2), top + 2*BORDER_PAD, (width / 2), height - BORDER_PAD];
        } else {
        	//otherwise, use the veritical layout
            mDataFont = vLayoutFontId;
            mDataFontAscent = Gfx.getFontAscent(mDataFont);

            mHPX = BORDER_PAD + (vLayoutWidth / 2) - (mHPUnitsWidth / 2);
            mHPY = top + BORDER_PAD + (vLayoutHeight / 2) - (mDataFontAscent / 2);
            if (height < 150) {
            	// for small layouts we have to compress the text due to circular screens.
              	mHPY += (vLayoutHeight*3 / 16);
            }

            mHCX = BORDER_PAD + (vLayoutWidth / 2) - (mHCUnitsWidth / 2);
            mHCY = mHPY + BORDER_PAD + vLayoutHeight ;

            if (height < 150) {
            	// for small layouts we have to compress the text due to circular screens.
            	mHCY -= (2*vLayoutHeight*3 / 16);
            }

            //Do not use a separator line for vertical layout
            separator = null;
        }
        xCenter = dc.getWidth() / 2;
        yCenter = dc.getHeight() / 2;
    }

    /**
     * @brief Find a font suitable for displaying a data field.
     */
    function selectDataFont(dc, width, height) {
        var fontId = null;
        var dimensions;

        /*
         * This takes advantage of the fact that these font identifiers are numbered
         * contiguously.
         */
        for(fontId = Gfx.FONT_NUMBER_THAI_HOT; fontId >= Gfx.FONT_XTINY; fontId--) {
            dimensions = dc.getTextDimensions("88.88", fontId);
            if ((dimensions[0] < width) && (dimensions[1] < height)) {
                //If this font fits, it is the biggest one that does
                break;
            }
        }
        return fontId;
    }

    /**
     * @brief Process an update event, redrawing the screen as needed.
     */
    function onUpdate(dc) {
        var bgColor = getBackgroundColor();
        var fgColor = Gfx.COLOR_WHITE;

        if (bgColor == Gfx.COLOR_WHITE) {
            fgColor = Gfx.COLOR_BLACK;
        }

        dc.setColor(fgColor, bgColor);
        dc.clear();

        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);

        // Update status
        if (bsxSensor == null) {
        	/*
        	 * This message should never happen, unless there are no ANT+ resource left on the
        	 * device.
        	 */
            dc.drawText(xCenter, yCenter, Gfx.FONT_MEDIUM, "No Channel!", Gfx.TEXT_JUSTIFY_CENTER);
        } else if (true == bsxSensor.searching) {
        	var howLong = Time.now().value() - bsxSensor.searchStart;
        	var message = null;

        	if (howLong < 5) {
        		/*
        		 * Splash for the first 5 seconds.
        		 */
        		dc.setColor(BSX_ORANGE, Gfx.COLOR_BLACK);
        		dc.clear();
        		dc.setColor(BSX_ORANGE, Gfx.COLOR_TRANSPARENT);
        		message = "BSXinsight";
        	} else if (bsxSensor.gDeviceState != BSXinsightSensor.INSIGHT_STATE_RUNNING) {
        		/*
        		 * "Waiting until the device has completed the connection process at least once.
        		 */
        		message = "Waiting";
	        } else {
	        	/*
	        	 * "Reconnecting" after the device has had an activity started.
	        	 */
	        	message = "Reconnecting";
	        }
        	dc.drawText(xCenter, yCenter, Gfx.FONT_MEDIUM, message, Gfx.TEXT_JUSTIFY_CENTER);
        } else {
            var x;
            var y;
			var message = null;

			if (bsxSensor.page_80 != null && bsxSensor.page_80.manufacturer != 0) {
				// DEBUG
				//System.println("Manufacturer = " + bsxSensor.page_80.manufacturer);

				if (bsxSensor.page_80.manufacturer != bsxSensor.ANT_BSX_MAN_ID) {
					// DEBUG
					//System.println("State = " + bsxSensor.gDeviceState);

					if (bsxSensor.gDeviceState == BSXinsightSensor.INSIGHT_STATE_RUNNING) {
						// DEBUG
						//System.println("Unsupported device.");
						/*
					 	 * Unsupported device type.
					 	 */
					 	bsxSensor.stopActivity();
        			}
				}
			}

			var totalHemo = bsxSensor.data.totalHemoConcentration;
            var HemoConc = totalHemo <= 40.0 ? totalHemo.format("%.2f"):"--.--";

			var curHemoPercent = bsxSensor.data.currentHemoPercent;
            var HemoPerc = curHemoPercent <= 100.0 ? curHemoPercent.format("%.1f"):"--.-";

			var shouldDraw = true;

			if (bsxSensor.gDeviceState != BSXinsightSensor.INSIGHT_STATE_RUNNING && bsxSensor.gDeviceState != BSXinsightSensor.INSIGHT_STATE_UNKNOWN) {
				switch(bsxSensor.gDeviceState) {
				case BSXinsightSensor.INSIGHT_STATE_STARTING:
					message = "Starting";
					shouldDraw = false;
					break;
				case BSXinsightSensor.INSIGHT_STATE_STOPPING:
					message = "Saving";
					shouldDraw = false;
					break;
				case BSXinsightSensor.INSIGHT_STATE_STOPPED:
					message = "Saved";
					shouldDraw = false;
					break;
				}
			}

			if (shouldDraw) {
		        //Draw Hemoglobin Concnetration
		        dc.drawText(mHCX, mHCY, mDataFont, HemoConc, Gfx.TEXT_JUSTIFY_CENTER);
	            x = mHCX + (dc.getTextWidthInPixels(HemoConc, mDataFont) / 2) + UNITS_SPACING;
	            y = mHCY + mDataFontAscent - Gfx.getFontAscent(mUnitsFont);
	            dc.drawText(x, y, mUnitsFont, mHCUnitsString, Gfx.TEXT_JUSTIFY_LEFT);

		        //Draw Hemoglobin Percentage
		        dc.drawText(mHPX, mHPY, mDataFont, HemoPerc, Gfx.TEXT_JUSTIFY_CENTER);
	            x = mHPX + (dc.getTextWidthInPixels(HemoPerc, mDataFont) / 2) + UNITS_SPACING;
	            y = mHPY + mDataFontAscent - Gfx.getFontAscent(mUnitsFont);
	            dc.drawText(x, y, mUnitsFont, mHPUnitsString, Gfx.TEXT_JUSTIFY_LEFT);

	            if (separator != null) {
                	dc.setColor(fgColor, fgColor);
                	dc.drawLine(separator[0], separator[1], separator[2], separator[3]);
            	}
            } else {
				dc.drawText(xCenter, yCenter, Gfx.FONT_MEDIUM, message, Gfx.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    function onTimerStart() {
    	// DEBUG
    	//System.println("onTimerStart()");

    	if (mFitContributor != null) {
	        mFitContributor.setTimerRunning(true);
	    }
		bsxSensor.startActivity();
    }

    function onTimerStop() {
    	// DEBUG
    	//System.println("onTimerStop()");

    	if (mFitContributor != null) {
	        mFitContributor.setTimerRunning(false);
		}
		bsxSensor.stopActivity();
    }

    function onTimerPause() {
    	if (mFitContributor != null) {
	        mFitContributor.setTimerRunning(false);
		}
    }

    function onTimerResume() {
    	if (mFitContributor != null) {
	        mFitContributor.setTimerRunning(true);
	    }
    }

    function onTimerLap() {
    	if (mFitContributor != null) {
	        mFitContributor.onTimerLap();
	    }
    }

    function onTimerReset() {
    	if (mFitContributor != null) {
	        mFitContributor.onTimerReset();
	    }
    }
}

//! main is the primary start point for a Monkeybrains application
class BSXField extends App.AppBase
{
	var bsxSensor;

	function initialize() {
		AppBase.initialize();
	}

    function onStart(state) {
        try {
            //Create the sensor object and open it
            bsxSensor = new BSXinsightSensor();
            bsxSensor.open();
        } catch(e instanceof Ant.UnableToAcquireChannelException) {
            //(e.getErrorMessage());
            bsxSensor = null;
        }
    }

    function getInitialView() {
    	return [new MO2Field(bsxSensor)];
        //return [cachedView];
    }

    function onStop(state) {
    	// if state is null apparently that means we are really exiting.
		// If it is non-null there is an expectation of returning.
    	if (state == null) {
    		var prevNow = Time.now().value();
			if (bsxSensor != null && bsxSensor.gDeviceState == BSXinsightSensor.INSIGHT_STATE_RUNNING) {
				/*
				 * Ensure the Insight is stopped -- the watch or computer is about to be stopped
				 * and there won't be another chance.
				 */
				for(var i = 0; i < STOP_ON_EXIT_RETRIES; i++) {
					bsxSensor.stopActivity();
				}
				var prevNow = Time.now().value();
				while((Time.now().value() - prevNow) < 1) {
				}
			}
		}
        return false;
    }
}
