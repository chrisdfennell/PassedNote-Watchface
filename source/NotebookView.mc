import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.Math;
import Toybox.Weather;
import Toybox.SensorHistory;
import Toybox.Application;

//
// Passed Note - a watch face that looks like a note teenagers pass to each
// other in class.
//
//   - Background: lined notebook filler paper - warm white, light-blue rules,
//     a red margin line, and three punch holes hugging the left curve.
//   - Every element is "written" in a different kid's handwriting, in blue or
//     black ballpoint (bitmap fonts baked from Segoe Script, Segoe Print, and
//     Ink Free by tools/gen_fonts.py):
//       date  "friday, jul 4"       neat printing, black pen
//       wx    doodled dynamic icon + "74°", condition word on the rule below
//       time  big loopy script, blue pen, with a squiggle underline
//       steps "steps: 8,432"        quick scrawl, black pen, heart rate
//             doodled in red beside them
//       batt  "batt: 82%" cursive blue + "energy: 87%" (Body Battery) black
//       plus calories + notification count on the last rule
//
// Text baselines sit ON the notebook rules (like real handwriting) using the
// per-font ascent ratios measured from the generated .fnt metrics.
//
// Everything scales relative to dc.getWidth()/getHeight() from a 454x454 base;
// monkey.jungle supplies correctly-sized fonts per panel.
//
// AMOLED Always-On: burn-in-safe minimal page - black screen, just the time
// in dim blue ink, shifted a little each minute.
//
class NotebookView extends WatchUi.WatchFace {

    // --- Screen geometry (resolved in onLayout) ---
    private var mWidth as Number = 0;
    private var mHeight as Number = 0;
    private var mCenterX as Number = 0;
    private var mCenterY as Number = 0;

    // --- State ---
    private var mIsSleep as Boolean = false;
    private var mBurnIn as Boolean = false;   // device requires burn-in protection (AMOLED)

    // --- Fonts (loaded in onLayout) ---
    private var mFontTime as Graphics.FontType or Null = null;
    private var mFontDate as Graphics.FontType or Null = null;
    private var mFontBody as Graphics.FontType or Null = null;
    private var mFontSmall as Graphics.FontType or Null = null;

    // Baseline position as a fraction of font height (ascent/lineHeight from the
    // generated .fnt files) so handwriting sits on the notebook rules.
    private const ASC_TIME  = 0.687;
    private const ASC_DATE  = 0.717;
    private const ASC_BODY  = 0.767;
    private const ASC_SMALL = 0.689;

    // --- Palette ------------------------------------------------------------
    private const C_PAPER      = 0xFCFAF0;  // warm filler-paper white
    private const C_RULE       = 0x9EC7E8;  // light blue rules
    private const C_MARGIN     = 0xE87878;  // red margin line
    private const C_HOLE_RIM   = 0xC8C4B4;  // punched-hole rim shadow
    private const C_INK_BLUE   = 0x1B3E9E;  // blue ballpoint
    private const C_INK_BLACK  = 0x282830;  // black ballpoint (soft, not pure black)
    private const C_INK_RED    = 0xC83250;  // red gel pen (doodles, heart rate)
    private const C_AOD_INK    = 0x3A4A78;  // dim blue for always-on

    // Yellow legal pad variant (PaperStyle 1).
    private const C_PAPER_LEGAL    = 0xF7E9B8;
    private const C_HOLE_RIM_LEGAL = 0xB8AE8C;

    // Rule spacing on the 454 base grid.
    private const RULE_SPACING = 38;

    // --- Settings (see resources/settings) ---
    private var mTimeInk as Number = 0;         // 0=blue 1=black 2=red
    private var mPaperStyle as Number = 0;      // 0=white filler 1=yellow legal
    private var mShowWeather as Boolean = true;
    private var mShowHr as Boolean = true;

    function initialize() {
        WatchFace.initialize();
        loadSettings();
    }

    // Read user settings; safe to call any time.
    function loadSettings() as Void {
        try {
            if (Application has :Properties) {
                var timeInk = Application.Properties.getValue("TimeInk");
                var paper = Application.Properties.getValue("PaperStyle");
                var weather = Application.Properties.getValue("ShowWeather");
                var hr = Application.Properties.getValue("ShowHeartRate");
                if (timeInk != null) { mTimeInk = timeInk; }
                if (paper != null) { mPaperStyle = paper; }
                if (weather != null) { mShowWeather = weather; }
                if (hr != null) { mShowHr = hr; }
            }
        } catch (e) {
            // keep defaults
        }
        if (mTimeInk < 0 || mTimeInk > 2) { mTimeInk = 0; }
        if (mPaperStyle < 0 || mPaperStyle > 1) { mPaperStyle = 0; }
    }

    // The pen chosen for the big time, and its dim always-on counterpart.
    private function timeInkColor() as Number {
        if (mTimeInk == 1) { return C_INK_BLACK; }
        if (mTimeInk == 2) { return C_INK_RED; }
        return C_INK_BLUE;
    }

    private function aodInkColor() as Number {
        if (mTimeInk == 1) { return 0x505058; }
        if (mTimeInk == 2) { return 0x703040; }
        return C_AOD_INK;
    }

    function onLayout(dc as Dc) as Void {
        mWidth = dc.getWidth();
        mHeight = dc.getHeight();
        mCenterX = mWidth / 2;
        mCenterY = mHeight / 2;

        var settings = System.getDeviceSettings();
        mBurnIn = (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection;

        mFontTime = WatchUi.loadResource(Rez.Fonts.NoteTime) as Graphics.FontType;
        mFontDate = WatchUi.loadResource(Rez.Fonts.NoteDate) as Graphics.FontType;
        mFontBody = WatchUi.loadResource(Rez.Fonts.NoteBody) as Graphics.FontType;
        mFontSmall = WatchUi.loadResource(Rez.Fonts.NoteSmall) as Graphics.FontType;
    }

    function onShow() as Void {
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
        mIsSleep = false;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        mIsSleep = true;
        WatchUi.requestUpdate();
    }

    // Scale a 454-base coordinate to this panel.
    private function s(v as Number) as Number {
        return v * mWidth / 454;
    }

    function onUpdate(dc as Dc) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        if (mIsSleep && mBurnIn) {
            drawAlwaysOn(dc);
            return;
        }

        drawPaper(dc);
        drawNote(dc);
    }

    // ------------------------------------------------------------------ paper

    // Lined filler paper: warm white, blue rules, red margin, punch holes.
    private function drawPaper(dc as Dc) as Void {
        var paper = (mPaperStyle == 1) ? C_PAPER_LEGAL : C_PAPER;
        dc.setColor(paper, paper);
        dc.clear();

        // Blue rules across the page.
        dc.setColor(C_RULE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(mWidth > 300 ? 2 : 1);
        var spacing = s(RULE_SPACING);
        var y = spacing;
        while (y < mHeight) {
            dc.drawLine(0, y, mWidth, y);
            y += spacing;
        }

        // Red margin line.
        dc.setColor(C_MARGIN, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(mWidth > 300 ? 2 : 1);
        var mx = s(96);
        dc.drawLine(mx, 0, mx, mHeight);

        // Three punch holes following the left curve of the screen.
        var r = mCenterX;
        var holeR = s(12);
        var inset = s(30);
        var dys = [-s(114), 0, s(114)] as Array<Number>;
        for (var i = 0; i < 3; i++) {
            var dy = dys[i];
            var chord = chordHalf(r, dy);
            var hx = mCenterX - chord + inset;
            var hy = mCenterY + dy;
            dc.setColor(0x181818, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(hx, hy, holeR);
            dc.setColor(mPaperStyle == 1 ? C_HOLE_RIM_LEGAL : C_HOLE_RIM, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(mWidth > 300 ? 2 : 1);
            dc.drawCircle(hx, hy, holeR);
        }
        dc.setPenWidth(1);
    }

    // ------------------------------------------------------------------- note

    private function drawNote(dc as Dc) as Void {
        var clock = System.getClockTime();
        var is24 = System.getDeviceSettings().is24Hour;
        var hour = clock.hour;
        if (!is24) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var timeStr = hour.toString() + ":" + clock.min.format("%02d");

        // Date line, rule 2: neat printing in black pen. "friday, jul 4"
        var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var days = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"] as Array<String>;
        var months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"] as Array<String>;
        var dateStr = days[(today.day_of_week as Number) - 1] + ", " +
                      months[(today.month as Number) - 1] + " " + today.day;
        writeOn(dc, mFontDate, ASC_DATE, dateStr, mCenterX, s(76), Graphics.TEXT_JUSTIFY_CENTER, C_INK_BLACK);

        // Weather, split across the two rules between the date and the time:
        // doodled icon + temperature, then the day's condition word.
        if (mShowWeather) {
            drawWeather(dc, s(114), s(152));
        }

        // The time, written HUGE in the chosen pen,
        // with an emphatic squiggle underline.
        var ink = timeInkColor();
        writeOn(dc, mFontTime, ASC_TIME, timeStr, mCenterX, s(266), Graphics.TEXT_JUSTIFY_CENTER, ink);
        drawSquiggle(dc, mCenterX - s(112), mCenterX + s(112), s(284), s(4), ink);

        // Stats, each in a different kid's handwriting.

        // steps in quick black scrawl (Ink Free), heart rate doodled in red
        // beside them, rule 9
        writeOn(dc, mFontBody, ASC_BODY, "steps: " + formatSteps(getSteps()),
                s(104), s(342), Graphics.TEXT_JUSTIFY_LEFT, C_INK_BLACK);
        if (mShowHr) {
            var hr = getHeartRate();
            var hrStr = (hr == null) ? "--" : hr.toString();
            drawHeart(dc, s(340), s(330), s(10), C_INK_RED);
            writeOn(dc, mFontBody, ASC_BODY, hrStr, s(358), s(342), Graphics.TEXT_JUSTIFY_LEFT, C_INK_RED);
        }

        // battery + Body Battery share rule 10, then calories and unread
        // messages squeeze onto the last rule.
        drawEnergyLine(dc, s(380));
        drawBottomLine(dc, s(418));
    }

    // Rule 10: device battery in blue cursive, Body Battery in black scrawl,
    // centered together. Body Battery is skipped when the device has no data.
    private function drawEnergyLine(dc as Dc, ruleY as Number) as Void {
        var battStr = "batt: " + getBattery() + "%";
        var bb = getBodyBattery();
        if (bb == null) {
            writeOn(dc, mFontSmall, ASC_SMALL, battStr, mCenterX, ruleY,
                    Graphics.TEXT_JUSTIFY_CENTER, C_INK_BLUE);
            return;
        }
        var bbStr = "energy: " + bb.toString() + "%";
        var gap = s(20);
        var battW = dc.getTextWidthInPixels(battStr, mFontSmall as Graphics.FontType);
        var bbW = dc.getTextWidthInPixels(bbStr, mFontBody as Graphics.FontType);
        var x = mCenterX - (battW + gap + bbW) / 2;
        writeOn(dc, mFontSmall, ASC_SMALL, battStr, x, ruleY, Graphics.TEXT_JUSTIFY_LEFT, C_INK_BLUE);
        writeOn(dc, mFontBody, ASC_BODY, bbStr, x + battW + gap, ruleY, Graphics.TEXT_JUSTIFY_LEFT, C_INK_BLACK);
    }

    // Last rule of the note: "1,850 cals" in blue cursive and the phone's
    // notification count in red pen, centered together on the rule.
    private function drawBottomLine(dc as Dc, ruleY as Number) as Void {
        var calStr = formatSteps(getCalories()) + " cals";
        var msgs = System.getDeviceSettings().notificationCount;
        var msgStr = (msgs == null || msgs == 0) ? "no msgs" : msgs.toString() + " msgs!";

        var gap = s(18);
        var calW = dc.getTextWidthInPixels(calStr, mFontSmall as Graphics.FontType);
        var msgW = dc.getTextWidthInPixels(msgStr, mFontSmall as Graphics.FontType);
        var x = mCenterX - (calW + gap + msgW) / 2;
        writeOn(dc, mFontSmall, ASC_SMALL, calStr, x, ruleY, Graphics.TEXT_JUSTIFY_LEFT, C_INK_BLUE);
        writeOn(dc, mFontSmall, ASC_SMALL, msgStr, x + calW + gap, ruleY, Graphics.TEXT_JUSTIFY_LEFT, C_INK_RED);
    }

    // Weather between the date and the time, two rules: the doodled icon
    // (dynamic, matches the conditions) + temperature in neat black printing,
    // then the condition word in blue cursive on the rule below. Skipped when
    // the watch has no weather data.
    private function drawWeather(dc as Dc, ruleY1 as Number, ruleY2 as Number) as Void {
        var wx = getWeather();
        if (wx == null) {
            return;
        }
        var temp = (wx[0] as Number).toString() + "°";
        var iconW = s(34);
        var gap = s(8);
        var tempW = dc.getTextWidthInPixels(temp, mFontDate as Graphics.FontType);
        var startX = mCenterX - (iconW + gap + tempW) / 2;
        drawWeatherIcon(dc, wx[2] as Number, startX + iconW / 2, ruleY1 - s(13));
        writeOn(dc, mFontDate, ASC_DATE, temp, startX + iconW + gap, ruleY1,
                Graphics.TEXT_JUSTIFY_LEFT, C_INK_BLACK);
        writeOn(dc, mFontSmall, ASC_SMALL, wx[1] as String, mCenterX, ruleY2,
                Graphics.TEXT_JUSTIFY_CENTER, C_INK_BLUE);
    }

    // --------------------------------------------------------------- doodles

    // Wavy underline squiggle (sine polyline).
    private function drawSquiggle(dc as Dc, x1 as Number, x2 as Number, y as Number, amp as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(mWidth > 300 ? 3 : 2);
        var step = s(6);
        if (step < 2) { step = 2; }
        var px = x1;
        var py = y;
        var x = x1 + step;
        while (x <= x2) {
            var t = (x - x1).toFloat() / s(28);
            var ny = y + (amp * Math.sin(t * 6.2832)).toNumber();
            dc.drawLine(px, py, x, ny);
            px = x;
            py = ny;
            x += step;
        }
        dc.setPenWidth(1);
    }

    // Little doodle heart (two lobes + point).
    private function drawHeart(dc as Dc, x as Number, y as Number, r as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var lobe = (r * 0.55).toNumber();
        if (lobe < 2) { lobe = 2; }
        var lx = x - lobe;
        var rx = x + lobe;
        var ly = y - (r * 0.35).toNumber();
        dc.fillCircle(lx, ly, lobe);
        dc.fillCircle(rx, ly, lobe);
        dc.fillPolygon([[x - r, ly], [x + r, ly], [x, y + r]] as Array<[Numeric, Numeric]>);
    }

    // Weather icon kinds returned by getWeather().
    private const WX_SUN    = 0;
    private const WX_PARTLY = 1;
    private const WX_CLOUD  = 2;
    private const WX_RAIN   = 3;
    private const WX_SNOW   = 4;
    private const WX_STORM  = 5;

    // Doodled weather icon, blue ballpoint (red lightning for storms),
    // centered at (x, y).
    private function drawWeatherIcon(dc as Dc, kind as Number, x as Number, y as Number) as Void {
        dc.setPenWidth(mWidth > 300 ? 2 : 1);

        if (kind == WX_SUN || kind == WX_PARTLY) {
            // sun: a circle with rays scribbled around it
            var sx = (kind == WX_PARTLY) ? x - s(5) : x;
            var sy = (kind == WX_PARTLY) ? y - s(5) : y;
            var r = (kind == WX_PARTLY) ? s(7) : s(9);
            dc.setColor(C_INK_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(sx, sy, r);
            for (var i = 0; i < 8; i++) {
                var ang = i * 0.7854;  // 45 degrees
                var c = Math.cos(ang);
                var sn = Math.sin(ang);
                dc.drawLine(sx + (c * (r + s(3))).toNumber(), sy + (sn * (r + s(3))).toNumber(),
                            sx + (c * (r + s(7))).toNumber(), sy + (sn * (r + s(7))).toNumber());
            }
        }

        if (kind == WX_SNOW) {
            // snowflake: three crossed strokes
            var fr = s(11);
            dc.setColor(C_INK_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x, y - fr, x, y + fr);
            dc.drawLine(x - (fr * 0.87).toNumber(), y - fr / 2, x + (fr * 0.87).toNumber(), y + fr / 2);
            dc.drawLine(x - (fr * 0.87).toNumber(), y + fr / 2, x + (fr * 0.87).toNumber(), y - fr / 2);
        }

        if (kind == WX_PARTLY || kind == WX_CLOUD || kind == WX_RAIN || kind == WX_STORM) {
            // cloud: three bumps and a flat bottom, shifted down for rain/storm
            var cy = (kind == WX_RAIN || kind == WX_STORM) ? y - s(5) : y;
            var cx = (kind == WX_PARTLY) ? x + s(4) : x;
            dc.setColor(C_INK_BLUE, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx - s(7), cy + s(2), s(5));
            dc.drawCircle(cx, cy - s(2), s(7));
            dc.drawCircle(cx + s(7), cy + s(2), s(5));
            dc.drawLine(cx - s(11), cy + s(7), cx + s(11), cy + s(7));
        }

        if (kind == WX_RAIN) {
            // three slanted rain strokes under the cloud
            dc.setColor(C_INK_BLUE, Graphics.COLOR_TRANSPARENT);
            for (var i = -1; i <= 1; i++) {
                var rx = x + i * s(7);
                dc.drawLine(rx + s(2), y + s(5), rx - s(2), y + s(12));
            }
        }

        if (kind == WX_STORM) {
            // red lightning zigzag under the cloud
            dc.setColor(C_INK_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x + s(2), y + s(2), x - s(3), y + s(8));
            dc.drawLine(x - s(3), y + s(8), x + s(2), y + s(8));
            dc.drawLine(x + s(2), y + s(8), x - s(2), y + s(14));
        }

        dc.setPenWidth(1);
    }

    // ------------------------------------------------------------- always-on

    // Burn-in-safe AMOLED always-on page: black, just the time in dim blue
    // ink, nudged a little each minute.
    private function drawAlwaysOn(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var clock = System.getClockTime();
        var is24 = System.getDeviceSettings().is24Hour;
        var hour = clock.hour;
        if (!is24) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
        }
        var timeStr = hour.toString() + ":" + clock.min.format("%02d");

        var dx = ((clock.min % 7) - 3) * s(2);
        var dy = (((clock.min / 7) % 5) - 2) * s(2);
        var fh = dc.getFontHeight(mFontTime as Graphics.FontType);
        dc.setColor(aodInkColor(), Graphics.COLOR_TRANSPARENT);
        dc.drawText(mCenterX + dx, mCenterY - fh / 2 + dy, mFontTime as Graphics.FontType,
                    timeStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // -------------------------------------------------------------- plumbing

    // Draw text with its baseline sitting on a notebook rule. ascRatio is the
    // font's ascent as a fraction of its height (from the .fnt metrics).
    private function writeOn(dc as Dc, font as Graphics.FontType or Null, ascRatio as Float,
                             text as String, x as Number, ruleY as Number,
                             justify as Graphics.TextJustification, color as Number) as Void {
        if (font == null) {
            return;
        }
        var fh = dc.getFontHeight(font);
        var yTop = ruleY - (fh * ascRatio).toNumber();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, yTop, font, text, justify);
    }

    // Half chord length of the screen circle at vertical offset dy from center.
    private function chordHalf(r as Number, dy as Number) as Number {
        var d = dy < 0 ? -dy : dy;
        if (d >= r) {
            return 0;
        }
        return Math.sqrt((r * r - d * d).toFloat()).toNumber();
    }

    // ------------------------------------------------------------------ data

    private function getSteps() as Number {
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            return info.steps as Number;
        }
        return 0;
    }

    // "8432" -> "8,432" (real notes always have the comma)
    private function formatSteps(n as Number) as String {
        if (n < 1000) {
            return n.toString();
        }
        return (n / 1000).toString() + "," + (n % 1000).format("%03d");
    }

    // Body Battery (0-100) from sensor history, or null when unsupported.
    private function getBodyBattery() as Number or Null {
        if ((Toybox has :SensorHistory) && (SensorHistory has :getBodyBatteryHistory)) {
            try {
                var it = SensorHistory.getBodyBatteryHistory({:period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST});
                if (it != null) {
                    var sample = it.next();
                    if (sample != null && sample.data != null) {
                        return (sample.data as Float).toNumber();
                    }
                }
            } catch (e) {
                // fall through
            }
        }
        return null;
    }

    private function getCalories() as Number {
        var info = ActivityMonitor.getInfo();
        if (info != null && (info has :calories) && info.calories != null) {
            return info.calories as Number;
        }
        return 0;
    }

    private function getBattery() as Number {
        var stats = System.getSystemStats();
        if (stats != null && stats.battery != null) {
            return (stats.battery + 0.5).toNumber();
        }
        return 0;
    }

    // Current weather as [temp (display units), condition word, icon kind],
    // or null when unavailable. The condition words are kept short and
    // lowercase so they read like the rest of the note.
    private function getWeather() as Array or Null {
        try {
            if (Toybox has :Weather) {
                var cc = Weather.getCurrentConditions();
                if (cc != null && cc.temperature != null) {
                    var temp = cc.temperature as Numeric;
                    var settings = System.getDeviceSettings();
                    if ((settings has :temperatureUnits) && (settings.temperatureUnits != System.UNIT_METRIC)) {
                        temp = temp * 9.0 / 5.0 + 32.0;
                    }
                    var word = "nice out";
                    var kind = WX_SUN;
                    var cond = (cc.condition != null) ? cc.condition as Number : -1;
                    if (cond == 6 || cond == 12 || cond == 28 || cond == 32 ||
                        cond == 36 || cond == 41 || cond == 42) {
                        word = "storms!";
                        kind = WX_STORM;
                    } else if (cond == 4 || cond == 7 || cond == 16 || cond == 17 ||
                               cond == 18 || cond == 19 || cond == 21 || cond == 34 ||
                               cond == 43 || cond == 44 || cond == 46 || cond == 47 ||
                               cond == 48 || cond == 49 || cond == 50 || cond == 51) {
                        word = "snowy";
                        kind = WX_SNOW;
                    } else if (cond == 3 || cond == 11 || cond == 13 || cond == 14 ||
                               cond == 15 || cond == 24 || cond == 25 || cond == 26 ||
                               cond == 27 || cond == 31 || cond == 45) {
                        word = "rainy";
                        kind = WX_RAIN;
                    } else if (cond == 8 || cond == 9 || cond == 29 || cond == 30 ||
                               cond == 33 || cond == 35 || cond == 37 || cond == 38 ||
                               cond == 39) {
                        word = "foggy";
                        kind = WX_CLOUD;
                    } else if (cond == 2 || cond == 20 || cond == 52) {
                        word = "cloudy";
                        kind = WX_CLOUD;
                    } else if (cond == 5) {
                        word = "windy";
                        kind = WX_CLOUD;
                    } else if (cond == 1 || cond == 22) {
                        word = "sorta sunny";
                        kind = WX_PARTLY;
                    } else if (cond == 0 || cond == 23 || cond == 40) {
                        word = "sunny";
                        kind = WX_SUN;
                    }
                    return [Math.round(temp.toFloat()).toNumber(), word, kind];
                }
            }
        } catch (e) {
            // fall through
        }
        return null;
    }

    private function getHeartRate() as Number or Null {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate;
        }
        if (ActivityMonitor has :getHeartRateHistory) {
            var it = ActivityMonitor.getHeartRateHistory(1, true);
            if (it != null) {
                var sample = it.next();
                if (sample != null && sample.heartRate != null &&
                    sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                    return sample.heartRate;
                }
            }
        }
        return null;
    }
}
