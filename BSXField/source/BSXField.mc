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


var fonts = [Gfx.FONT_XTINY,Gfx.FONT_TINY,Gfx.FONT_SMALL,Gfx.FONT_MEDIUM,Gfx.FONT_LARGE,
             Gfx.FONT_NUMBER_MILD,Gfx.FONT_NUMBER_MEDIUM,Gfx.FONT_NUMBER_HOT,Gfx.FONT_NUMBER_THAI_HOT];


class MO2Field extends Ui.DataField
{
    //Label Variables
    hidden var mLabelString = "BSXinsight";
    hidden var mLabelFont = Gfx.FONT_TINY;
    hidden var mLabelX;
    hidden var mLabelY = 5; //Does not change

    //Hemoglobin Concentration variables
	hidden var mHCUnitsString = "tHb";
    hidden var mHCUnitsWidth;
    hidden var mHCX;
    hidden var mHCY;
    hidden var mHCMaxWidth;

    //Hemoglobin Percentage variables
    hidden var mHPUnitsString = "%";
    hidden var mHPUnitsWidth;
    hidden var mHPX;
    hidden var mHPY;
    hidden var mHPMaxWidth;

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

    const INSIGHT_STATE_UNKNOWN = 0;
    const INSIGHT_STATE_STARTING = 1;
    const INSIGHT_STATE_RUNNING = 2;
    const INSIGHT_STATE_STOPPING = 3;
    const INSIGHT_STATE_STOPPED = 4;

    var mDeviceState = INSIGHT_STATE_UNKNOWN;
    hidden var startStopCounter;

    const TEXT_STATE_NONE = 0;
    const TEXT_STATE_STARTING = 1;
    const TEXT_STATE_STOPPING = 2;

    hidden var startStopTextState = TEXT_STATE_NONE;

    //! Constructor
    function initialize(sensor) {
    	DataField.initialize();

		bsxSensor = sensor;
        mFitContributor = new MO2FitContributor(self);

        mDeviceState = INSIGHT_STATE_UNKNOWN;
        startStopCounter = 0;
        startStopTextState = TEXT_STATE_NONE;
    }

    function compute(info) {
    	if (info != null && mDeviceState == INSIGHT_STATE_RUNNING) {
	        mFitContributor.compute(bsxSensor);
	    }

    	if (info) {
        	if (info.startTime) {
        		if (mDeviceState == INSIGHT_STATE_UNKNOWN) {
        			if (! bsxSensor.searching) {
						mDeviceState = INSIGHT_STATE_STOPPED;
					}
        		}

        		if (mDeviceState == INSIGHT_STATE_STOPPED) {
        			/*
        			 * @todo - This needs to NOT start the device.
        			 */
        			// if unset or stopped
        			mDeviceState = INSIGHT_STATE_STARTING;
        			startStopCounter = START_RETRIES;
        		} else if (mDeviceState == INSIGHT_STATE_STARTING) {
        			// if already started
					if (startStopCounter > 0) {
						startStopCounter -= 1;
					} else {
						mDeviceState = INSIGHT_STATE_RUNNING;
					}
				} else if (mDeviceState == INSIGHT_STATE_RUNNING) {
					// Do nothing -- device is operating normally.
				} else if (mDeviceState == INSIGHT_STATE_STOPPING) {
					if (startStopCounter > 0) {
						startStopCounter -= 1;
					} else {
						mDeviceState = INSIGHT_STATE_STOPPED;
					}
				} else if (mDeviceState == INSIGHT_STATE_STOPPED) {
					// Do nothing -- device is stopped.
        		}
        	} else {
        		if (mDeviceState == INSIGHT_STATE_UNKNOWN) {
        			// Don't do anything if the state is unknown.
        		} else if (mDeviceState == INSIGHT_STATE_RUNNING) {
        			mDeviceState = INSIGHT_STATE_STOPPING;
        			startStopCounter = STOP_RETRIES;
        		} else if (mDeviceState == INSIGHT_STATE_STOPPING) {
					if (startStopCounter > 0) {
						startStopCounter -= 1;
					} else {
						// The device isn't responding to stop activity commands, stop sending them.
						mDeviceState = INSIGHT_STATE_STOPPED;
					}
        		}
        	}
        }

		if (bsxSensor == null || bsxSensor.searching == true) {
			return;
		}

       	startStopTextState = TEXT_STATE_NONE;
       	if (mDeviceState != INSIGHT_STATE_UNKNOWN && startStopCounter != 0) {
			if (mDeviceState == INSIGHT_STATE_STARTING) {
				if (bsxSensor.data.currentHemoPercent > 100.0) {
					bsxSensor.startActivity();
					startStopTextState = TEXT_STATE_STARTING;
				} else {
					startStopCounter = 0;
					mDeviceState = INSIGHT_STATE_RUNNING;
				}
			} else if (mDeviceState == INSIGHT_STATE_STOPPING) {
				if (bsxSensor.data.currentHemoPercent <= 100.0) {
					/*
					 * The "stop activity" command will be sent until invalid data is
					 * received or the counter runs out.
					 */
					bsxSensor.stopActivity();
					startStopTextState = TEXT_STATE_STOPPING;
				} else {
					startStopCounter = 0;
					mDeviceState = INSIGHT_STATE_STOPPED;
				}
			}
		}
    }

    function onLayout(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();

		var top = BORDER_PAD;

    	//Center the field label
        mLabelX = width / 2;

        var vLayoutWidth;
        var vLayoutHeight;
        var vLayoutFontIdx;

        var hLayoutWidth;
        var hLayoutHeight;
        var hLayoutFontIdx;

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
        hLayoutFontIdx = selectDataFont(dc, (hLayoutWidth - mHCUnitsWidth), hLayoutHeight - (hLayoutHeight / 8));

        vLayoutWidth = width - (2 * BORDER_PAD);
        vLayoutHeight = (height - top - (4 * BORDER_PAD)) / 2;
        vLayoutFontIdx = selectDataFont(dc, (vLayoutWidth - mHCUnitsWidth), vLayoutHeight-(vLayoutHeight/8));

        //Use the horizontal layout if it supports a larger font
        if (hLayoutFontIdx > vLayoutFontIdx) {
            mDataFont = fonts[hLayoutFontIdx];
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
            mDataFont = fonts[vLayoutFontIdx];
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
        var testString = "88.88"; //Dummy string to test data width
        var fontIdx;
        var dimensions;

        //Search through fonts from biggest to smallest
        for(fontIdx = (fonts.size() - 1); fontIdx > 0; fontIdx--) {
            dimensions = dc.getTextDimensions(testString, fonts[fontIdx]);
            if ((dimensions[0] <= width) && (dimensions[1] <= height)) {
                //If this font fits, it is the biggest one that does
                break;
            }
        }
        return fontIdx;
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

        	if (howLong < 5) {
        		/*
        		 * Splash for the first 5 seconds.
        		 */
        		dc.setColor(BSX_ORANGE, Gfx.COLOR_BLACK);
        		dc.clear();
        		dc.setColor(BSX_ORANGE, Gfx.COLOR_TRANSPARENT);
        		dc.drawText(xCenter, yCenter, Gfx.FONT_MEDIUM, "BSXinsight", Gfx.TEXT_JUSTIFY_CENTER);
        	} else if (mDeviceState != INSIGHT_STATE_RUNNING) {
        		/*
        		 * "Waiting until the device has completed the connection process at least once.
        		 */
	            dc.drawText(xCenter, yCenter, Gfx.FONT_MEDIUM, "Waiting", Gfx.TEXT_JUSTIFY_CENTER);
	        } else {
	        	/*
	        	 * "Reconnecting" after the device has had an activity started.
	        	 */
	            dc.drawText(xCenter, yCenter, Gfx.FONT_MEDIUM, "Reconnecting", Gfx.TEXT_JUSTIFY_CENTER);
	        }
        } else {
            var x;
            var y;
            var HemoConc = bsxSensor.data.totalHemoConcentration.format("%.2f");
            var HemoPerc = bsxSensor.data.currentHemoPercent.format("%.1f");

			var totalHemo = bsxSensor.data.totalHemoConcentration;
			var curHemoPercent = bsxSensor.data.currentHemoPercent;

			var shouldDraw = true;

			if (mDeviceState != INSIGHT_STATE_RUNNING && mDeviceState != INSIGHT_STATE_UNKNOWN) {
				switch(mDeviceState) {
				case INSIGHT_STATE_STARTING:
					dc.drawText(xCenter, yCenter, Gfx.FONT_MEDIUM, "Starting", Gfx.TEXT_JUSTIFY_CENTER);
					shouldDraw = false;
					break;
				case INSIGHT_STATE_STOPPING:
					dc.drawText(xCenter, yCenter, Gfx.FONT_MEDIUM, "Saving", Gfx.TEXT_JUSTIFY_CENTER);
					shouldDraw = false;
					break;
				case INSIGHT_STATE_STOPPED:
					dc.drawText(xCenter, yCenter, Gfx.FONT_MEDIUM, "Saved", Gfx.TEXT_JUSTIFY_CENTER);
					shouldDraw = false;
					break;
				}
			}

			if (shouldDraw) {
				if (totalHemo > 40.0) {
					/*
					 * Concentrations over 40 g/dl are invalid.
					 */
					HemoConc = "--.--";
				}

		        //Draw Hemoglobin Concnetration
		        dc.drawText(mHCX, mHCY, mDataFont, HemoConc, Gfx.TEXT_JUSTIFY_CENTER);
	            x = mHCX + (dc.getTextWidthInPixels(HemoConc, mDataFont) / 2) + UNITS_SPACING;
	            y = mHCY + mDataFontAscent - Gfx.getFontAscent(mUnitsFont);
	            dc.drawText(x, y, mUnitsFont, mHCUnitsString, Gfx.TEXT_JUSTIFY_LEFT);

				if (curHemoPercent > 100.0) {
					/*
					 * Values over 100 are invalid.
					 */
					HemoPerc = "--.-";
				}

		        //Draw Hemoglobin Percentage
		        dc.drawText(mHPX, mHPY, mDataFont, HemoPerc, Gfx.TEXT_JUSTIFY_CENTER);
	            x = mHPX + (dc.getTextWidthInPixels(HemoPerc, mDataFont) / 2) + UNITS_SPACING;
	            y = mHPY + mDataFontAscent - Gfx.getFontAscent(mUnitsFont);
	            dc.drawText(x, y, mUnitsFont, mHPUnitsString, Gfx.TEXT_JUSTIFY_LEFT);
            }

            if (separator != null && shouldDraw) {
                dc.setColor(fgColor, fgColor);
                dc.drawLine(separator[0], separator[1], separator[2], separator[3]);
            }
        }
    }

    function onTimerStart() {
        mFitContributor.setTimerRunning(true);

        var payload = new[8];

        payload[0] = 0x10;			// Command page.
        payload[1] = 0x01;			// Start command.
        payload[2] = 0xFF;			// Required value;
        payload[3] = 0x00;			// Use UTC time -- no offset.

        var now = Time.now().value();
        for (var i = 0;i < 4;i++) {
        	payload[4 + i] = (now & 0xFF);
        	now = now >> 8;
        }
        var message = new Ant.Message();
        message.setPayload(payload);
        var result = bsxSensor.sendAcknowledge(message);
    }

    function onTimerStop() {
        mFitContributor.setTimerRunning(false);

        var payload = new[8];

        payload[0] = 0x10;			// Command page.
        payload[1] = 0x02;			// Stop command.
        payload[2] = 0xFF;			// Required value;
        payload[3] = 0x00;			// Use UTC time -- no offset.

        var now = Time.now().value();
        for (var i = 0;i < 4;i++) {
        	payload[4 + i] = (now & 0xFF);
        	now = now >> 8;
        }
        var message = new Ant.Message();
        message.setPayload(payload);
        var result = bsxSensor.sendAcknowledge(message);
    }

    function onTimerPause() {
        mFitContributor.setTimerRunning(false);
    }

    function onTimerResume() {
        mFitContributor.setTimerRunning(true);
    }

    function onTimerLap() {
        mFitContributor.onTimerLap();
    }

    function onTimerReset() {
        mFitContributor.onTimerReset();
    }
}

//! main is the primary start point for a Monkeybrains application
class BSXField extends App.AppBase
{
	var bsxSensor;
    var cachedView;

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
    	cachedView = new MO2Field(bsxSensor);
        return [cachedView];
    }

    function onStop(state) {
    	// if state is null apparently that means we are really exiting.
		// If it is non-null there is an expectation of returning.
    	if (state == null) {
    		var prevNow = Time.now().value();
			if (cachedView != null && cachedView.mDeviceState == INSIGHT_STATE_RUNNING) {
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
