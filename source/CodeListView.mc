using Toybox.WatchUi as Ui;
using Toybox.Application.Properties as Properties;

module CodeListView {

    function getConfiguredSlots() {
        var slots = [];
        for (var i = 1; i <= 8; i += 1) {
            var name = Properties.getValue("Slot" + i + "Name");
            if (name != null && name.length() > 0) {
                slots.add(i);
            }
        }
        return slots;
    }

    function buildBarcodeView(slotNumber) {
        var type = Properties.getValue("Slot" + slotNumber + "Type");
        var value = Properties.getValue("Slot" + slotNumber + "Value");
        var name = Properties.getValue("Slot" + slotNumber + "Name");
        return new BarcodeView(type, value, name);
    }

    // Builds the Menu2 shown at app launch: one row per configured slot
    // (slots are configured via the Garmin Connect mobile app's App Settings).
    function buildMenu() {
        var menu = new Ui.Menu2({:title => "My Codes"});
        var any = false;
        for (var i = 1; i <= 8; i += 1) {
            var name = Properties.getValue("Slot" + i + "Name");
            if (name != null && name.length() > 0) {
                menu.addItem(new Ui.MenuItem(name, null, "slot" + i, {}));
                any = true;
            }
        }
        if (!any) {
            menu.addItem(new Ui.MenuItem(
                "No codes yet",
                "Add codes in the Garmin Connect app's settings for this app",
                "none",
                {}
            ));
        }
        return menu;
    }
}
