
using Toybox.Communications;
using Toybox.WatchUi;


class ConnectIQLIFXDelegate extends WatchUi.BehaviorDelegate {
    // Base delegate, doesn't do much as the main menu is called once it's ready to be loaded
    var notify;
    // Set up the callback to the view
    function initialize() {
        WatchUi.BehaviorDelegate.initialize();
    }

    // Handle back button press to exit safely
    function onBack() {
        System.println("ConnectIQLIFXDelegate: back pressed");
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}

class LifxMainInputDelegate extends WatchUi.MenuInputDelegate {
    // Handles the main menu selection
    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item) {
        // Builds the sub menus for each option

        System.println("Recieved item: " + item);
        if (item == :toggle_all_lights) {
            var loading_view = new SendingSignalView(true);
            var loading_delegate = new ConnectIQLIFXDelegate();
            WatchUi.switchToView(loading_view, loading_delegate, WatchUi.SLIDE_DOWN);
            $.LIFX_API_OBJ.applying_selection = true;
            WatchUi.requestUpdate();
            $.LIFX_API_OBJ.toggle_visible();

        } else if (item == :apply_scene) {
            var menu = new WatchUi.Menu();
            var delegate;
            menu.setTitle("Select Scene");
            var num_scenes = $.LIFX_API_OBJ.scenes.size();
            System.println("Number of scenes to display: "+ num_scenes);
            for( var i = 0; i < num_scenes; i++ ) {
                menu.addItem($.LIFX_API_OBJ.scenes[i]["name"], $.LIFX_API_OBJ.scenes[i]["scene_num"]);
            }

            delegate = new LifxSceneInputDelegate();
            WatchUi.pushView(menu, delegate, WatchUi.SLIDE_DOWN);
        } else if (item == :toggle_light) {
            var rooms = $.LIFX_API_OBJ.rooms;
            var menu = new WatchUi.Menu();
            menu.setTitle("Select room");
            System.println("Number of rooms to display: " + rooms.size());
            if (rooms.size() == 0) {
                menu.addItem("No lights to show", :none);
            }
            for( var i = 0; i < rooms.size(); i++ ) {
                menu.addItem(rooms[i]["name"], rooms[i]["room_num"]);
            }
            WatchUi.pushView(menu, new LifxRoomInputDelegate(), WatchUi.SLIDE_DOWN);

        } else if (item == :exit) {
            System.exit();
        } else {
            System.println("Item not recognised: " + item);
        }
    }
}


class LifxSceneInputDelegate extends WatchUi.MenuInputDelegate {
    // Handles selection of a scene to apply
    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item) {
        var loading_view = new SendingSignalView(false);
        var loading_delegate = new ConnectIQLIFXDelegate();
        WatchUi.pushView(loading_view, loading_delegate, WatchUi.SLIDE_DOWN);
        $.LIFX_API_OBJ.applying_selection = true;
        System.println("Recieved item: " + item);
        var selected_scene = $.LIFX_API_OBJ.scenes[item];
        $.LIFX_API_OBJ.set_scene(selected_scene["uuid"]);
    }
}

class LifxRoomInputDelegate extends WatchUi.MenuInputDelegate {
    // Handles selection of a room, then shows that room's lights
    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item) {
        System.println("Recieved room: " + item);
        if (item == :none) {
            return;
        }
        var room = $.LIFX_API_OBJ.rooms[item];
        var light_nums = room["lights"];
        var menu = new WatchUi.Menu();
        menu.setTitle(room["name"]);
        menu.addItem("Whole room", :whole_room);
        for( var i = 0; i < light_nums.size(); i++ ) {
            menu.addItem($.LIFX_API_OBJ.lights[light_nums[i]]["label"], light_nums[i]);
        }
        WatchUi.pushView(menu, new LifxLightInputDelegate(item), WatchUi.SLIDE_DOWN);
    }
}

class LifxLightInputDelegate extends WatchUi.MenuInputDelegate {
    // Handles selection of a light (or the whole room) to toggle
    var room_num;

    function initialize(room) {
        MenuInputDelegate.initialize();
        room_num = room;
    }

    function onMenuItem(item) {
        var loading_view = new SendingSignalView(false);
        var loading_delegate = new ConnectIQLIFXDelegate();
        WatchUi.pushView(loading_view, loading_delegate, WatchUi.SLIDE_DOWN);
        $.LIFX_API_OBJ.applying_selection = true;
        System.println("Recieved item: " + item);
        if (item == :whole_room) {
            $.LIFX_API_OBJ.toggle_lights($.LIFX_API_OBJ.rooms[room_num]["lights"]);
        } else {
            $.LIFX_API_OBJ.toggle_lights([item]);
        }
    }
}
