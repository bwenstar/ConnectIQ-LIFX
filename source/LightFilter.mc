// Helpers for choosing which lights are shown, and grouping them into rooms

using Toybox.Application;
using Toybox.Lang;

module LightFilter {

    // Reads a string setting, returning "" when it isn't set
    function read_setting(key) {
        var value = null;
        if (Toybox.Application has :Properties) {
            value = Application.Properties.getValue(key);
        } else {
            value = Application.getApp().getProperty(key);
        }
        if (value instanceof Lang.String) {
            return value;
        }
        return "";
    }

    // Splits a comma separated setting into trimmed, lower case entries
    function parse_list(value) {
        var entries = [];
        if (!(value instanceof Lang.String)) {
            return entries;
        }
        var rest = value;
        while (true) {
            var idx = rest.find(",");
            var part = (idx == null) ? rest : rest.substring(0, idx);
            part = trim(part).toLower();
            if (part.length() > 0) {
                entries.add(part);
            }
            if (idx == null) {
                break;
            }
            rest = rest.substring(idx + 1, rest.length());
        }
        return entries;
    }

    function trim(s) {
        var chars = s.toCharArray();
        var start = 0;
        var end = chars.size();
        while (start < end && chars[start] == ' ') {
            start++;
        }
        while (end > start && chars[end - 1] == ' ') {
            end--;
        }
        return s.substring(start, end);
    }

    // True if an entry names the light's label, group, location, or "location/group"
    function matches(light, entries) {
        var label = light["label"].toLower();
        var group = light["group"]["name"].toLower();
        var location = light["location"]["name"].toLower();
        var location_group = location + "/" + group;
        for (var i = 0; i < entries.size(); i++) {
            var e = entries[i];
            if (e.equals(label) || e.equals(group) || e.equals(location) || e.equals(location_group)) {
                return true;
            }
        }
        return false;
    }

    // An empty show list means "show everything"; the hide list always wins
    function is_visible(light, show, hide) {
        if (show.size() > 0 && !matches(light, show)) {
            return false;
        }
        return !matches(light, hide);
    }

    // Case insensitive "a comes before b"
    function str_less(a, b) {
        var ca = a.toLower().toCharArray();
        var cb = b.toLower().toCharArray();
        var n = (ca.size() < cb.size()) ? ca.size() : cb.size();
        for (var i = 0; i < n; i++) {
            var x = ca[i].toNumber();
            var y = cb[i].toNumber();
            if (x != y) {
                return x < y;
            }
        }
        return ca.size() < cb.size();
    }

    // Sorts an array of dictionaries in place by a string field
    function sort_by(arr, key) {
        for (var i = 1; i < arr.size(); i++) {
            var item = arr[i];
            var j = i - 1;
            while (j >= 0 && str_less(item[key], arr[j][key])) {
                arr[j + 1] = arr[j];
                j--;
            }
            arr[j + 1] = item;
        }
        return arr;
    }

    // Groups lights by their LIFX group. Each room is
    // {"name" => String, "lights" => [indices into lights]}, sorted by name.
    // A room name used in more than one location gets the location added.
    function build_rooms(lights) {
        var rooms = [];
        var by_group = {};
        for (var i = 0; i < lights.size(); i++) {
            var gid = lights[i]["group"]["id"];
            if (!by_group.hasKey(gid)) {
                var room = {
                    "name" => lights[i]["group"]["name"],
                    "location" => lights[i]["location"]["name"],
                    "lights" => []
                };
                by_group.put(gid, room);
                rooms.add(room);
            }
            by_group[gid]["lights"].add(i);
        }

        var names = [];
        for (var i = 0; i < rooms.size(); i++) {
            names.add((rooms[i]["name"] as Lang.String).toLower());
        }
        for (var i = 0; i < rooms.size(); i++) {
            var count = 0;
            for (var j = 0; j < names.size(); j++) {
                if (names[j].equals(names[i])) {
                    count++;
                }
            }
            if (count > 1) {
                rooms[i]["name"] = rooms[i]["name"] + " (" + rooms[i]["location"] + ")";
            }
        }
        sort_by(rooms, "name");
        for (var i = 0; i < rooms.size(); i++) {
            rooms[i].put("room_num", i);  // Used as a menu identifier, has to be a number
        }
        return rooms;
    }
}
