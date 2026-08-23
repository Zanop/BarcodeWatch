using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;

class BarcodeView extends Ui.View {

    const TYPE_QR = 0;
    const TYPE_CODE128 = 1;
    const TYPE_EAN13 = 2;
    const TYPE_EAN8 = 3;

    var mType;
    var mValue;
    var mName;

    function initialize(type, value, name) {
        View.initialize();
        mType = type;
        mValue = value;
        mName = name;
    }

    function onUpdate(dc) {
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_WHITE);
        dc.clear();
        dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);

        var w = dc.getWidth();
        var h = dc.getHeight();
        var labelHeight = 20;
        if (mName != null && mName.length() > 0) {
            dc.drawText(w / 2, 2, Gfx.FONT_XTINY, mName, Gfx.TEXT_JUSTIFY_CENTER);
        } else {
            labelHeight = 0;
        }

        if (mValue == null || mValue.length() == 0) {
            dc.drawText(w / 2, h / 2, Gfx.FONT_SMALL, "No value set", Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            return;
        }

        if (mType == TYPE_QR) {
            var matrix = QrEncoder.encode(mValue);
            if (matrix == null) {
                drawError(dc, w, h, QrEncoder.lastError);
                return;
            }
            drawMatrix(dc, matrix, w, h - labelHeight, labelHeight);
        } else if (mType == TYPE_CODE128) {
            var bits = Code128Encoder.encode(mValue);
            if (bits == null) {
                drawError(dc, w, h, Code128Encoder.lastError);
                return;
            }
            drawBars(dc, bits, w, h - labelHeight, labelHeight);
        } else if (mType == TYPE_EAN13) {
            var bits = EanEncoder.encode13(mValue);
            if (bits == null) {
                drawError(dc, w, h, EanEncoder.lastError);
                return;
            }
            drawBars(dc, bits, w, h - labelHeight, labelHeight);
        } else if (mType == TYPE_EAN8) {
            var bits = EanEncoder.encode8(mValue);
            if (bits == null) {
                drawError(dc, w, h, EanEncoder.lastError);
                return;
            }
            drawBars(dc, bits, w, h - labelHeight, labelHeight);
        } else {
            drawError(dc, w, h, "Unknown code type");
        }
    }

    function drawError(dc, w, h, msg) {
        dc.drawText(w / 2, h / 2 - 20, Gfx.FONT_XTINY, "Couldn't render code:", Gfx.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h / 2, Gfx.FONT_XTINY, msg, Gfx.TEXT_JUSTIFY_CENTER);
    }

    // QR: matrix is an array of arrays of 0/1. Quiet zone kept small (2 modules)
    // since the display is tiny - most modern phone scanners tolerate this at
    // close range, but if you have scanning trouble, shorten the code text so
    // it fits a lower QR version (bigger modules).
    function drawMatrix(dc, matrix, w, h, top) {
        var n = matrix.size();
        var quiet = 2;
        var avail = (w < h) ? w : h;
        var scale = avail / (n + quiet * 2);
        if (scale < 1) { scale = 1; }
        var total = (n + quiet * 2) * scale;
        var ox = (w - total) / 2;
        var oy = top + (h - total) / 2;

        for (var r = 0; r < n; r += 1) {
            var row = matrix[r];
            for (var c = 0; c < n; c += 1) {
                if (row[c] == 1) {
                    dc.fillRectangle(ox + (quiet + c) * scale, oy + (quiet + r) * scale, scale, scale);
                }
            }
        }
    }

    // 1D barcodes (Code128 / EAN): bits is a String of '1'/'0' module values.
    // Quiet zone is relaxed from the printed-barcode spec (normally ~9-10
    // modules) down to what fits, since the screen is only 176px wide - keep
    // your code text short (under ~15 characters for Code128) for a module
    // width that scans reliably.
    function drawBars(dc, bits, w, h, top) {
        var n = bits.length();
        var quiet = 6;
        var scale = w / (n + quiet * 2);
        if (scale < 1) { scale = 1; }
        var total = (n + quiet * 2) * scale;
        var ox = (w - total) / 2;
        if (ox < 0) { ox = 0; }
        var barH = (h * 60) / 100;
        var oy = top + (h - barH) / 2;

        for (var i = 0; i < n; i += 1) {
            var ch = bits.substring(i, i + 1);
            if (ch.equals("1")) {
                dc.fillRectangle(ox + (quiet + i) * scale, oy, scale, barH);
            }
        }

        dc.drawText(w / 2, oy + barH + 4, Gfx.FONT_XTINY, mValue, Gfx.TEXT_JUSTIFY_CENTER);
    }
}
