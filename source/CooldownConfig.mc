import Toybox.Lang;

// Parsed configuration decoded from the "cooldownSeed" web-UI seed string.
// All widget behavior comes from this object - there are no other settings.
class CooldownConfig {
    var officialEndEpoch as Number;
    var nextYearStartEpoch as Number;
    var accentColor as Number;
    var schoolStartHour as Number;
    var schoolStartMinute as Number;

    // Index 0=Sun..6=Sat.
    var dayEnabled as Array<Boolean>;
    var dayEndHour as Array<Number>;
    var dayEndMinute as Array<Number>;

    function initialize(
        endEpoch as Number,
        nextStartEpoch as Number,
        accent as Number,
        startHour as Number,
        startMinute as Number,
        enabled as Array<Boolean>,
        endHour as Array<Number>,
        endMinute as Array<Number>
    ) {
        officialEndEpoch = endEpoch;
        nextYearStartEpoch = nextStartEpoch;
        accentColor = accent;
        schoolStartHour = startHour;
        schoolStartMinute = startMinute;
        dayEnabled = enabled;
        dayEndHour = endHour;
        dayEndMinute = endMinute;
    }

    // Splits `s` on single-character delimiter `delim` (Monkey C's String has no split()).
    static function splitStr(s as String, delim as String) as Array<String> {
        var result = [] as Array<String>;
        var start = 0;
        var idx = s.find(delim);
        while (idx != null) {
            result.add(s.substring(start, idx) as String);
            start = idx + delim.length();
            idx = s.substring(start, s.length()).find(delim);
            if (idx != null) { idx += start; }
        }
        result.add(s.substring(start, s.length()) as String);
        return result;
    }

    // Decodes a base36 string (0-9, a-z) into a Number.
    static function fromBase36(s as String) as Number {
        var digits = "0123456789abcdefghijklmnopqrstuvwxyz";
        var value = 0;
        for (var i = 0; i < s.length(); i++) {
            var c = s.substring(i, i + 1);
            var d = digits.find(c);
            if (d == null) { return 0; }
            value = value * 36 + d;
        }
        return value;
    }

    // Seed format (produced by web/index.html):
    // 1|E=<b36 epoch>|N=<b36 epoch>|W=<decimal bitmask, bit0=Sun..bit6=Sat>|T=<b36 endMinutes Sun,Mon,...,Sat>|C=<decimal 0-7>|S=<b36 startMinutes>
    static function parse(seed as String) as CooldownConfig? {
        if (seed.length() < 2 or !seed.substring(0, 2).equals("1|")) {
            return null;
        }
        var sections = CooldownConfig.splitStr(seed.substring(2, seed.length()), "|");
        var eStr = null;
        var nStr = null;
        var wStr = null;
        var tStr = null;
        var cStr = null;
        var sStr = null;
        for (var i = 0; i < sections.size(); i++) {
            var s = sections[i] as String;
            if (s.find("E=") == 0) { eStr = s.substring(2, s.length()); }
            else if (s.find("N=") == 0) { nStr = s.substring(2, s.length()); }
            else if (s.find("W=") == 0) { wStr = s.substring(2, s.length()); }
            else if (s.find("T=") == 0) { tStr = s.substring(2, s.length()); }
            else if (s.find("C=") == 0) { cStr = s.substring(2, s.length()); }
            else if (s.find("S=") == 0) { sStr = s.substring(2, s.length()); }
        }
        if (eStr == null or nStr == null or wStr == null or tStr == null or cStr == null or sStr == null) {
            return null;
        }

        var tParts = CooldownConfig.splitStr(tStr as String, ",");
        if (tParts.size() != 7) {
            return null;
        }

        var days = (wStr as String).toNumber();
        var accent = (cStr as String).toNumber();
        if (days == null or accent == null) {
            return null;
        }

        var enabled = [] as Array<Boolean>;
        var endHour = [] as Array<Number>;
        var endMinute = [] as Array<Number>;
        for (var i = 0; i < 7; i++) {
            enabled.add(((days >> i) & 1) == 1);
            var minutes = CooldownConfig.fromBase36(tParts[i] as String);
            endHour.add(minutes / 60);
            endMinute.add(minutes % 60);
        }

        var startMinutes = CooldownConfig.fromBase36(sStr as String);

        return new CooldownConfig(
            CooldownConfig.fromBase36(eStr as String),
            CooldownConfig.fromBase36(nStr as String),
            accent,
            startMinutes / 60,
            startMinutes % 60,
            enabled,
            endHour,
            endMinute
        );
    }
}
