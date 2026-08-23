// EAN-13 / EAN-8 retail barcode encoder.
// Tables validated against python-barcode's ean charset + a zbar scan
// round-trip before being ported here.
module EanEncoder {

    var CODES_A = [
        "0001101","0011001","0010011","0111101","0100011",
        "0110001","0101111","0111011","0110111","0001011"
    ];
    var CODES_C = [
        "1110010","1100110","1101100","1000010","1011100",
        "1001110","1010000","1000100","1001000","1110100"
    ];
    var EDGE = "101";
    var MIDDLE = "01010";
    var LEFT_PATTERN = [
        "AAAAAA","AABABB","AABBAB","AABBBA","ABAABB",
        "ABBAAB","ABBBAA","ABABAB","ABABBA","ABBABA"
    ];

    var lastError = "";

    function digitsOnly(text) {
        var bytes = text.toUtf8Array();
        for (var i = 0; i < bytes.size(); i += 1) {
            if (bytes[i] < 48 || bytes[i] > 57) { return false; }
        }
        return true;
    }

    function charToDigit(text, i) {
        return text.toUtf8Array()[i] - 48;
    }

    // Returns bit string for a 13-digit EAN, or null. Accepts 12 or 13 input
    // digits; if 13 given, the 13th (check) digit is ignored and recomputed.
    function encode13(text) {
        if (!digitsOnly(text) || (text.length() != 12 && text.length() != 13)) {
            lastError = "EAN-13 needs 12 or 13 digits";
            return null;
        }
        var digits = new [12];
        for (var i = 0; i < 12; i += 1) { digits[i] = charToDigit(text, i); }

        var s = 0;
        for (var i = 0; i < 12; i += 1) {
            s += digits[i] * ((i % 2 == 0) ? 1 : 3);
        }
        var check = (10 - (s % 10)) % 10;

        var all = new [13];
        for (var i = 0; i < 12; i += 1) { all[i] = digits[i]; }
        all[12] = check;

        var first = all[0];
        var pattern = LEFT_PATTERN[first];
        var bits = EDGE;
        for (var i = 0; i < 6; i += 1) {
            var d = all[1 + i];
            var set = pattern.substring(i, i + 1);
            if (set.equals("A")) {
                bits += CODES_A[d];
            } else {
                bits += CODES_B(d);
            }
        }
        bits += MIDDLE;
        for (var i = 0; i < 6; i += 1) {
            bits += CODES_C[all[7 + i]];
        }
        bits += EDGE;
        return bits;
    }

    // Subset B patterns are the bitwise-reverse-complement of subset A;
    // this is the standard relationship, kept as a function to avoid a
    // second literal table (and the transcription risk that comes with it).
    function CODES_B(d) {
        var a = CODES_A[d];
        var out = "";
        var i = a.length() - 1;
        while (i >= 0) {
            var ch = a.substring(i, i + 1);
            out += ch.equals("1") ? "0" : "1";
            i -= 1;
        }
        return out;
    }

    // Returns bit string for an 8-digit EAN, or null. Accepts 7 or 8 input
    // digits; if 8 given, the 8th (check) digit is ignored and recomputed.
    function encode8(text) {
        if (!digitsOnly(text) || (text.length() != 7 && text.length() != 8)) {
            lastError = "EAN-8 needs 7 or 8 digits";
            return null;
        }
        var digits = new [7];
        for (var i = 0; i < 7; i += 1) { digits[i] = charToDigit(text, i); }

        var s = 0;
        for (var i = 0; i < 7; i += 1) {
            s += digits[i] * ((i % 2 == 0) ? 3 : 1);
        }
        var check = (10 - (s % 10)) % 10;

        var all = new [8];
        for (var i = 0; i < 7; i += 1) { all[i] = digits[i]; }
        all[7] = check;

        var bits = EDGE;
        for (var i = 0; i < 4; i += 1) { bits += CODES_A[all[i]]; }
        bits += MIDDLE;
        for (var i = 0; i < 4; i += 1) { bits += CODES_C[all[4 + i]]; }
        bits += EDGE;
        return bits;
    }
}
