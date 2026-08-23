using Toybox.Lang as Lang;

// Minimal QR encoder: Byte mode only, fixed mask 0, ECC level L, versions 1-10.
// Adds an ECI (UTF-8) designator automatically when the text contains non-ASCII bytes.
// Ported and cross-checked against the `qrcode` Python reference library + zbar
// scan round-trips before being translated here - see chat history for the
// validation harness. Keep the structure identical to that reference if you
// ever need to extend it (e.g. more versions).
module QrEncoder {

    // ---- GF(256) tables for Reed-Solomon ----
    var EXP = new [512];
    var LOG = new [256];
    var tablesReady = false;

    function initTables() {
        if (tablesReady) { return; }
        var x = 1;
        for (var i = 0; i < 255; i += 1) {
            EXP[i] = x;
            LOG[x] = i;
            x = x << 1;
            if ((x & 0x100) != 0) {
                x = x ^ 0x11d;
            }
        }
        for (var i = 255; i < 512; i += 1) {
            EXP[i] = EXP[i - 255];
        }
        tablesReady = true;
    }

    function gmul(a, b) {
        if (a == 0 || b == 0) { return 0; }
        return EXP[LOG[a] + LOG[b]];
    }

    function polyMul(p, q) {
        var r = new [p.size() + q.size() - 1];
        for (var i = 0; i < r.size(); i += 1) { r[i] = 0; }
        for (var i = 0; i < p.size(); i += 1) {
            var pc = p[i];
            if (pc == 0) { continue; }
            for (var j = 0; j < q.size(); j += 1) {
                var qc = q[j];
                if (qc == 0) { continue; }
                r[i + j] = r[i + j] ^ gmul(pc, qc);
            }
        }
        return r;
    }

    function rsGeneratorPoly(nsym) {
        var g = [1];
        for (var i = 0; i < nsym; i += 1) {
            g = polyMul(g, [1, EXP[i]]);
        }
        return g;
    }

    function rsEncode(data, nsym) {
        var gen = rsGeneratorPoly(nsym);
        var res = new [data.size() + nsym];
        for (var i = 0; i < data.size(); i += 1) { res[i] = data[i]; }
        for (var i = data.size(); i < res.size(); i += 1) { res[i] = 0; }
        for (var i = 0; i < data.size(); i += 1) {
            var coef = res[i];
            if (coef != 0) {
                for (var j = 0; j < gen.size(); j += 1) {
                    res[i + j] = res[i + j] ^ gmul(gen[j], coef);
                }
            }
        }
        var out = new [nsym];
        for (var i = 0; i < nsym; i += 1) { out[i] = res[data.size() + i]; }
        return out;
    }

    // version -> [total_data_codewords, ec_codewords_per_block]
    function qrL(version) {
        var t = {
            1 => [19, 7], 2 => [34, 10], 3 => [55, 15], 4 => [80, 20], 5 => [108, 26],
            6 => [136, 18], 7 => [156, 20], 8 => [194, 24], 9 => [232, 30], 10 => [274, 18]
        };
        return t[version];
    }

    // version -> array of [blockCount, dataLenPerBlock] groups
    function qrLBlocks(version) {
        var t = {
            6 => [[2, 68]], 7 => [[2, 78]], 8 => [[2, 97]], 9 => [[2, 116]],
            10 => [[2, 68], [2, 69]]
        };
        if (t.hasKey(version)) { return t[version]; }
        return null;
    }

    function qrSize(version) {
        return 17 + 4 * version;
    }

    function charCountBits(version) {
        if (version <= 9) { return 8; }
        return 16;
    }

    class BitWriter {
        var bits;
        function initialize() {
            bits = [];
        }
        function put(val, n) {
            var i = n - 1;
            while (i >= 0) {
                bits.add((val >> i) & 1);
                i -= 1;
            }
        }
    }

    function encodeBytes(version, dataBytes, useEci) {
        initTables();
        var params = qrL(version);
        var totalDataCw = params[0];
        var ecPerBlock = params[1];

        var bw = new BitWriter();
        if (useEci) {
            bw.put(0x7, 4);   // ECI mode indicator
            bw.put(26, 8);    // ECI designator 26 = UTF-8
        }
        bw.put(0x4, 4);       // byte mode indicator
        bw.put(dataBytes.size(), charCountBits(version));
        for (var i = 0; i < dataBytes.size(); i += 1) {
            bw.put(dataBytes[i], 8);
        }

        var capBits = totalDataCw * 8;
        var term = 4;
        if (capBits - bw.bits.size() < term) { term = capBits - bw.bits.size(); }
        if (term < 0) { term = 0; }
        bw.put(0, term);
        while ((bw.bits.size() % 8) != 0) {
            bw.bits.add(0);
        }

        var dataCw = [];
        var i = 0;
        while (i < bw.bits.size()) {
            var v = 0;
            for (var k = 0; k < 8; k += 1) {
                v = (v << 1) | bw.bits[i + k];
            }
            dataCw.add(v);
            i += 8;
        }
        var padBytes = [0xEC, 0x11];
        var pi = 0;
        while (dataCw.size() < totalDataCw) {
            dataCw.add(padBytes[pi % 2]);
            pi += 1;
        }

        var blocksSpec = qrLBlocks(version);
        var blocks = [];
        if (blocksSpec != null) {
            var idx = 0;
            for (var g = 0; g < blocksSpec.size(); g += 1) {
                var count = blocksSpec[g][0];
                var dlen = blocksSpec[g][1];
                for (var c = 0; c < count; c += 1) {
                    var b = new [dlen];
                    for (var k = 0; k < dlen; k += 1) { b[k] = dataCw[idx + k]; }
                    blocks.add(b);
                    idx += dlen;
                }
            }
        } else {
            var b = new [dataCw.size()];
            for (var k = 0; k < dataCw.size(); k += 1) { b[k] = dataCw[k]; }
            blocks.add(b);
        }

        var ecBlocks = [];
        for (var bi = 0; bi < blocks.size(); bi += 1) {
            ecBlocks.add(rsEncode(blocks[bi], ecPerBlock));
        }

        var maxLen = 0;
        for (var bi = 0; bi < blocks.size(); bi += 1) {
            if (blocks[bi].size() > maxLen) { maxLen = blocks[bi].size(); }
        }
        var finalData = [];
        for (var k = 0; k < maxLen; k += 1) {
            for (var bi = 0; bi < blocks.size(); bi += 1) {
                if (k < blocks[bi].size()) { finalData.add(blocks[bi][k]); }
            }
        }
        var finalEc = [];
        for (var k = 0; k < ecPerBlock; k += 1) {
            for (var bi = 0; bi < ecBlocks.size(); bi += 1) {
                finalEc.add(ecBlocks[bi][k]);
            }
        }
        var allCw = [];
        for (var k = 0; k < finalData.size(); k += 1) { allCw.add(finalData[k]); }
        for (var k = 0; k < finalEc.size(); k += 1) { allCw.add(finalEc[k]); }
        return allCw;
    }

    // alignment pattern centers per version
    function alignCenters(version) {
        var t = {
            1 => [], 2 => [6, 18], 3 => [6, 22], 4 => [6, 26], 5 => [6, 30],
            6 => [6, 34], 7 => [6, 22, 38], 8 => [6, 24, 42], 9 => [6, 26, 46], 10 => [6, 28, 50]
        };
        return t[version];
    }

    function buildMatrix(version, allCodewords) {
        var n = qrSize(version);
        var m = new [n];
        var reserved = new [n];
        for (var r = 0; r < n; r += 1) {
            m[r] = new [n];
            reserved[r] = new [n];
            for (var c = 0; c < n; c += 1) {
                m[r][c] = 0;
                reserved[r][c] = false;
            }
        }

        // finder patterns
        var finderOrigins = [[0, 0], [0, n - 7], [n - 7, 0]];
        for (var f = 0; f < 3; f += 1) {
            var r0 = finderOrigins[f][0];
            var c0 = finderOrigins[f][1];
            for (var i = -1; i < 8; i += 1) {
                for (var j = -1; j < 8; j += 1) {
                    var rr = r0 + i;
                    var cc = c0 + j;
                    if (rr >= 0 && rr < n && cc >= 0 && cc < n) {
                        var val = 0;
                        if (i == -1 || i == 7 || j == -1 || j == 7) {
                            val = 0;
                        } else if (i == 0 || i == 6 || j == 0 || j == 6) {
                            val = 1;
                        } else if (i >= 2 && i <= 4 && j >= 2 && j <= 4) {
                            val = 1;
                        } else {
                            val = 0;
                        }
                        m[rr][cc] = val;
                        reserved[rr][cc] = true;
                    }
                }
            }
        }

        // timing patterns
        for (var i = 8; i < n - 8; i += 1) {
            var v = (i % 2 == 0) ? 1 : 0;
            m[6][i] = v; reserved[6][i] = true;
            m[i][6] = v; reserved[i][6] = true;
        }

        // dark module
        m[4 * version + 9][8] = 1;
        reserved[4 * version + 9][8] = true;

        // alignment patterns
        var centers = alignCenters(version);
        for (var ci = 0; ci < centers.size(); ci += 1) {
            for (var cj = 0; cj < centers.size(); cj += 1) {
                var r = centers[ci];
                var c = centers[cj];
                if ((r <= 8 && c <= 8) || (r <= 8 && c >= n - 9) || (r >= n - 9 && c <= 8)) {
                    continue;
                }
                for (var i = -2; i <= 2; i += 1) {
                    for (var j = -2; j <= 2; j += 1) {
                        var ai = (i < 0) ? -i : i;
                        var aj = (j < 0) ? -j : j;
                        var mx = (ai > aj) ? ai : aj;
                        var val = (mx == 1) ? 0 : 1;
                        m[r + i][c + j] = val;
                        reserved[r + i][c + j] = true;
                    }
                }
            }
        }

        // format info reserved area
        for (var i = 0; i < 9; i += 1) {
            reserved[8][i] = true;
            reserved[i][8] = true;
        }
        for (var i = n - 8; i < n; i += 1) {
            reserved[8][i] = true;
        }
        for (var i = n - 7; i < n; i += 1) {
            reserved[i][8] = true;
        }

        // version info for v>=7
        if (version >= 7) {
            for (var i = 0; i < 6; i += 1) {
                for (var j = 0; j < 3; j += 1) {
                    reserved[n - 11 + j][i] = true;
                    reserved[i][n - 11 + j] = true;
                }
            }
            var vg = 0x1F25;
            var val = version << 12;
            var work = val;
            for (var i = 5; i >= 0; i -= 1) {
                if ((work & (1 << (i + 12))) != 0) {
                    work = work ^ (vg << i);
                }
            }
            var vbits18 = val | work;
            var vb = new [18];
            for (var i = 0; i < 18; i += 1) { vb[i] = (vbits18 >> i) & 1; }
            for (var i = 0; i < 18; i += 1) {
                var row = i % 3;
                var col = i / 3;
                m[n - 11 + row][col] = vb[i];
                m[col][n - 11 + row] = vb[i];
            }
        }

        // data placement, zigzag, mask 0
        var bits = [];
        for (var bi = 0; bi < allCodewords.size(); bi += 1) {
            var byteVal = allCodewords[bi];
            for (var k = 7; k >= 0; k -= 1) {
                bits.add((byteVal >> k) & 1);
            }
        }
        var bitIdx = 0;
        var totalBits = bits.size();
        var col = n - 1;
        var upward = true;
        while (col > 0) {
            if (col == 6) {
                col -= 1;
                continue;
            }
            var rowRange = [];
            if (upward) {
                var r = n - 1;
                while (r >= 0) { rowRange.add(r); r -= 1; }
            } else {
                var r = 0;
                while (r < n) { rowRange.add(r); r += 1; }
            }
            for (var ri = 0; ri < rowRange.size(); ri += 1) {
                var row = rowRange[ri];
                var cols = [col, col - 1];
                for (var cidx = 0; cidx < 2; cidx += 1) {
                    var c = cols[cidx];
                    if (reserved[row][c]) { continue; }
                    var bitVal = 0;
                    if (bitIdx < totalBits) { bitVal = bits[bitIdx]; }
                    bitIdx += 1;
                    var maskOn = ((row + c) % 2 == 0) ? 1 : 0;
                    m[row][c] = bitVal ^ maskOn;
                }
            }
            upward = !upward;
            col -= 2;
        }

        // format info: ECL=L (01), mask=0 (000)
        var fmt = (0x1 << 3) | 0;
        var g = 0x537;
        var fval = fmt << 10;
        var fwork = fval;
        for (var i = 4; i >= 0; i -= 1) {
            if ((fwork & (1 << (i + 10))) != 0) {
                fwork = fwork ^ (g << i);
            }
        }
        var fmtBits15 = (fval | fwork) ^ 0x5412;
        var fb = new [15];
        for (var i = 0; i < 15; i += 1) { fb[i] = (fmtBits15 >> i) & 1; }

        for (var i = 0; i < 6; i += 1) { m[8][i] = fb[i]; }
        m[8][7] = fb[6];
        m[8][8] = fb[7];
        m[7][8] = fb[8];
        for (var i = 9; i < 15; i += 1) { m[14 - i][8] = fb[i]; }
        for (var i = 0; i < 8; i += 1) { m[8][n - 1 - i] = fb[i]; }
        for (var i = 8; i < 15; i += 1) { m[n - 15 + i][8] = fb[i]; }

        return m;
    }

    // Picks the smallest version (1-10) that fits, or returns null if too long.
    function pickVersion(dataBytes, useEci) {
        var hdrExtra = useEci ? 12 : 0;
        for (var v = 1; v <= 10; v += 1) {
            var cap = qrL(v)[0] * 8;
            var hdr = hdrExtra + 4 + charCountBits(v);
            if (dataBytes.size() * 8 + hdr <= cap) {
                return v;
            }
        }
        return null;
    }

    // Public entry point: text -> 2D matrix (array of array of 0/1), or null on failure.
    // On failure, lastError holds a short human-readable reason.
    var lastError = "";

    function encode(text) {
        var dataBytes = text.toUtf8Array();
        var useEci = false;
        for (var i = 0; i < dataBytes.size(); i += 1) {
            if (dataBytes[i] >= 0x80) { useEci = true; }
        }
        var version = pickVersion(dataBytes, useEci);
        if (version == null) {
            lastError = "Text too long for QR (max ~270 bytes)";
            return null;
        }
        var allCw = encodeBytes(version, dataBytes, useEci);
        return buildMatrix(version, allCw);
    }
}
