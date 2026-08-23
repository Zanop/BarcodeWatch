using Toybox.WatchUi as Ui;
using Toybox.Application.Properties as Properties;
using Toybox.Lang as Lang;

class CodeListDelegate extends Ui.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId() as Lang.String;
        if (id.equals("none")) {
            return;
        }
        // id looks like "slot3" -> slot number 3
        var numStr = id.substring(4, id.length());
        var i = numStr.toNumber();

        var name = Properties.getValue("Slot" + i + "Name");
        var type = Properties.getValue("Slot" + i + "Type");
        var value = Properties.getValue("Slot" + i + "Value");

        Ui.pushView(new BarcodeView(type, value, name), new BarcodeDelegate([i], 0), Ui.SLIDE_LEFT);
    }
}
