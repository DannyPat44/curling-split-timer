import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! The curling-sheet face for round, high-resolution screens: the split on
//! top, then a strip of ice showing the far end of the sheet (hog line, house,
//! back line, hack and boards) with a rock at the predicted stop position.
//! While the timer runs the rock slides back toward the hog line as the
//! split gets slower.
class SheetFace {
    private const SHEET_FROM = -24.0;
    private const SHEET_TO = 15.0;

    private const ICE = 0xD5E1EA;
    private const ICE_LINE = 0x7D93A6;
    private const HOG_RED = 0xE0282E;
    private const HOUSE_BLUE = 0x1F5BFF;
    private const HOUSE_RED = 0xE0282E;
    private const HOUSE_WHITE = 0xFFFFFF;
    private const GRANITE = 0x9BA3AB;
    private const HANDLE = 0xFFC93C;
    private const LABEL = 0x9ECFFF;

    function initialize() {
    }

    //! @param o what to show:
    //!     :big the split, "HIT" or the start prompt; :prompt true for a prompt;
    //!     :dim true to grey the big text; :placing true while the rock's spot
    //!     is being chosen; :running true while timing; :rockFeet where the
    //!     rock sits in feet past the tee, or null for none; :positionName its
    //!     spot's name; :end the end (0 before the game); :slots each of the
    //!     end's rocks as a Game.SLOT_* state; :thrower who throws next;
    //!     :button the button split and :buttonDelta its change from the
    //!     start; :strokes this end's brush strokes; :footer the bottom line
    function draw(dc as Dc, o as Dictionary) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var end = o[:end] as Number;
        if (end > 0) {
            // The end and whose rock is next, over a row of this end's rocks
            dc.setColor(LABEL, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.1, Graphics.FONT_XTINY, "END " + end + " · " + o[:thrower],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            drawRockRow(dc, w / 2, (h * 0.165).toNumber(), o[:slots] as Array<Number>);
        }

        if (o[:prompt] == true) {
            // Mid-game the prompt sits under the end line, where the split
            // goes, and smaller so it clears it on small screens
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, end > 0 ? h * 0.335 : h * 0.27, end > 0 ? Graphics.FONT_SMALL : Graphics.FONT_MEDIUM,
                o[:big] as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(o[:dim] == true ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var font = Graphics.FONT_NUMBER_HOT;
            if ((o[:big] as String).equals("HIT")) {
                dc.setColor(HOUSE_RED, Graphics.COLOR_TRANSPARENT);
                font = Graphics.FONT_LARGE;
            }
            dc.drawText(w / 2, h * 0.32, font, o[:big] as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var top = (h * 0.47).toNumber();
        var height = (h * 0.15).toNumber();
        drawSheet(dc, top, height);
        var rockFeet = o[:rockFeet];
        if (rockFeet != null) {
            var feet = rockFeet as Float;
            // A hit's spot is past the boards: show it against them
            if (feet > SHEET_TO - 1) {
                feet = SHEET_TO - 1;
            } else if (feet < SHEET_FROM) {
                feet = SHEET_FROM;
            }
            var rx = feetToX(dc, feet);
            var r = (height * 0.2).toNumber();
            var placing = o[:placing] == true;
            if (placing) {
                // Ring the rock being placed
                dc.setColor(HANDLE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(3);
                dc.drawCircle(rx, top + height / 2, r + 6);
                dc.setPenWidth(1);
            }
            drawRock(dc, rx, top + height / 2, r);
            dc.setColor(placing ? HANDLE : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, top + height + h * 0.075, Graphics.FONT_SMALL, o[:positionName] as String,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Brush strokes this end left of centre and ice speed right of it,
        // both anchored to the middle so a long count grows away from the
        // round edge and the two can't meet
        var statY = (h * 0.8).toNumber();
        var strokeText = (o[:strokes] as Number).toString();
        var strokeFont = dc.getTextWidthInPixels(strokeText, Graphics.FONT_TINY) > w * 0.18
            ? Graphics.FONT_XTINY : Graphics.FONT_TINY;
        var strokeRight = w / 2 - 16;
        var strokeLeft = strokeRight - dc.getTextWidthInPixels(strokeText, strokeFont);
        drawBroom(dc, strokeLeft - 20, statY - 4);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(strokeRight, statY, strokeFont, strokeText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        drawIceSpeed(dc, w / 2 + 16, statY, o[:button] as Number, o[:buttonDelta] as Number);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.885, Graphics.FONT_XTINY, o[:footer] as String,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! The split that reaches the button on this ice, after a tiny house,
    //! starting at `left`.
    //! Keen ice needs a slower (longer) split for the same draw, so a longer
    //! button split than the starting guess is fast ice: green; shorter is
    //! slow ice: red.
    private function drawIceSpeed(dc as Dc, left as Number, y as Number, button as Number, delta as Number) as Void {
        var text = (button / 1000.0).format("%.2f");
        var hx = left + 8;
        dc.setColor(HOUSE_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hx, y, 8);
        dc.setColor(HOUSE_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hx, y, 5);
        dc.setColor(HOUSE_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(hx, y, 3);
        var color = delta >= 50 ? 0x4CD964 : (delta <= -50 ? 0xFF5A5A : Graphics.COLOR_WHITE);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(hx + 13, y, Graphics.FONT_TINY, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! The end's rocks: grey once timed, red for hits, a dot for skipped
    //! ones and the wearer's own, an outline for the rest, the next ringed
    private function drawRockRow(dc as Dc, x as Number, y as Number, slots as Array<Number>) as Void {
        var gap = 18;
        var r = 5;
        var count = slots.size();
        for (var i = 0; i < count; ++i) {
            var rx = x + (i * 2 - (count - 1)) * gap / 2;
            var state = slots[i];
            if (state == Game.SLOT_HIT) {
                dc.setColor(HOUSE_RED, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(rx, y, r);
            } else if (state == Game.SLOT_THROWN) {
                dc.setColor(GRANITE, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(rx, y, r);
            } else if (state == Game.SLOT_SKIPPED || state == Game.SLOT_MINE) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(rx, y, 2);
            } else {
                dc.setColor(state == Game.SLOT_NEXT ? HANDLE : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawCircle(rx, y, r);
                dc.setPenWidth(1);
            }
        }
    }

    private function feetToX(dc as Dc, feet as Numeric) as Number {
        var left = dc.getWidth() * 0.06;
        var right = dc.getWidth() * 0.94;
        return (left + (feet - SHEET_FROM) / (SHEET_TO - SHEET_FROM) * (right - left)).toNumber();
    }

    private function drawSheet(dc as Dc, top as Number, height as Number) as Void {
        var left = feetToX(dc, SHEET_FROM);
        var right = feetToX(dc, SHEET_TO);
        var mid = top + height / 2;
        var foot = feetToX(dc, 1) - feetToX(dc, 0);
        dc.setColor(ICE, ICE);
        dc.fillRoundedRectangle(left, top, right - left, height, 6);

        // The house, clipped to the strip like the view from above the sheet
        dc.setClip(left, top, right - left, height);
        var tee = feetToX(dc, 0);
        var rings = [[6, HOUSE_BLUE], [4, HOUSE_WHITE], [2, HOUSE_RED], [0.5, HOUSE_WHITE]];
        for (var i = 0; i < rings.size(); ++i) {
            dc.setColor(rings[i][1] as Number, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tee, mid, (rings[i][0] as Numeric) * foot);
        }
        // White rings need an edge to show against the ice
        dc.setColor(ICE_LINE, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(tee, mid, 4 * foot);
        dc.clearClip();

        dc.setPenWidth(1);
        dc.setColor(ICE_LINE, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(left, mid, right, mid);
        dc.drawLine(tee, top, tee, top + height);
        var back = feetToX(dc, 6);
        dc.drawLine(back, top, back, top + height);
        dc.setPenWidth(3);
        dc.setColor(HOG_RED, Graphics.COLOR_TRANSPARENT);
        var hog = feetToX(dc, -21);
        dc.drawLine(hog, top, hog, top + height);
        dc.setPenWidth(1);

        // Hack and boards
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        var hack = feetToX(dc, 12);
        dc.fillRectangle(hack - 2, mid - foot, 4, foot * 2);
        dc.fillRoundedRectangle(right - 5, top, 5, height, 2);
    }

    //! A curling brush: a long shaft leaning right onto a flat pad
    private function drawBroom(dc as Dc, x as Number, y as Number) as Void {
        dc.setPenWidth(4);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x - 4, y + 9, x + 9, y - 14);
        dc.setPenWidth(1);
        dc.setColor(HOUSE_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x - 19, y + 8, 30, 9, 3);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x - 8, y + 5, 8, 4, 1);
    }

    private function drawRock(dc as Dc, x as Number, y as Number, r as Number) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r + 2);
        dc.setColor(GRANITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(HANDLE, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x - r * 0.75, y - r * 0.28, r * 1.5, r * 0.56, 2);
    }
}
