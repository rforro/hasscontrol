using Toybox.Application as App;
using Toybox.Attention as Attention;
using Toybox.WatchUi as Ui;
using Toybox.Timer;
using ControlMenu;
using Hass;

class EntityListController {
    hidden var _mEntities;
    hidden var _mTypes;
    hidden var _mIndex;

    function initialize(types) {
        _mTypes = types;
        _mIndex = 0;
        refreshEntities();
    }

    /**
    * Returns index of focused entity/page
    */
    function getIndex() {
        return _mIndex;
    }

    /**
    * Returns number of all imported entities
    */
    function getCount() {
        return _mEntities.size();
    }

    /**
    * Loads imported entity ids from HASS 
    */
    function refreshEntities() {
        _mEntities = [];
        var impEnt = Hass.getImportedEntities();

        for (var i = 0; i < impEnt.size(); i++) {
            if (_mTypes.indexOf(impEnt[i].substring(0, impEnt[i].find("."))) != -1) {
                _mEntities.add(impEnt[i]);
            }
        }

        if (_mIndex >= getCount()) {
            _mIndex = 0;
        }
    }
    
    /**
    * Returns current entity id
    */
    function getCurrentEntityId() {
        return _mEntities[_mIndex];
    }

    /**
    * Returns current entity type
    */    
    function getCurrentEntityType() {
    	if (getCount() == 0) {return null;}
        return _mEntities[_mIndex].substring(0, _mEntities[_mIndex].find("."));
    }

    /**
    * Returns attributes of current entity
    */
    function getCurrentEntityAttributes() {
        if (getCount() == 0) {return null;}
        return Hass.getEntityState(_mEntities[_mIndex]);
    }
    
    /**
    * Sets next entity index, rollover is handled
    */
    function setNextPage() {
        _mIndex += 1;
        if (_mIndex > getCount() - 1) {_mIndex = 0;}
    }
    
    /**
    * Sets previous entity index, rollover is handled
    */
    function setPreviousPage() {
        _mIndex -= 1;
        if (_mIndex < 0) {_mIndex = getCount() - 1;}
    }

    /**
    * Calls toggle action or opens extended entity view
    */
    function executeCurrentEntity() {
        if (getCount() == 0) {
            return false;
        }

        var curEntId = getCurrentEntityId();

        switch(getCurrentEntityType()) {
            case Hass.ENTITY_TYPE_LIGHT:
                return Ui.pushView(new EntityTypeLightView(curEntId), new EntityTypeLightDelegate(curEntId), Ui.SLIDE_RIGHT);
            default:
                var ret = Hass.toggleEntityState(curEntId, getCurrentEntityType(), getCurrentEntityAttributes()["state"]);
                if (Attention has :vibrate && ret) {Attention.vibrate([new Attention.VibeProfile(50, 100)]);}
                return ret;
        }
    }
}

class EntityListDelegate extends Ui.BehaviorDelegate {
    hidden var _mController;

    function initialize(controller) {
        BehaviorDelegate.initialize();
        _mController = controller;
    }

    function onMenu() {
        return ControlMenu.showRootMenu();
    }

    function onSelect() {
        return _mController.executeCurrentEntity();
    }

    function onNextPage() {
        _mController.setNextPage();
        Ui.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        _mController.setPreviousPage();
        Ui.requestUpdate();
        return true;
    }
}

class EntityListView extends Ui.View {
    hidden var _mController;
    hidden var _mLastIndex;
    hidden var _mTimerScrollBar;
    hidden var _mTimerScrollBarActive;
    hidden var _mShowScrollBar;

    function initialize(controller) {
        View.initialize();
        _mController = controller;
        _mLastIndex = null;
        _mTimerScrollBar = new Timer.Timer();
        _mTimerScrollBarActive = false;
        _mShowScrollBar = false;
    }

    function onShow() {
        _mController.refreshEntities();
    }

    /**
    * Draws entity icon based on its state
    */
    function drawEntityIcon(dc, state, type) {
        var vh = dc.getHeight();
        var vw = dc.getWidth();
        var cvw = vw / 2;
        var drawable = null;
        
        switch(type) {
            case Hass.ENTITY_TYPE_AUTOMATION:
                drawable = Ui.loadResource(state.equals(Hass.STATE_ON) ? Rez.Drawables.AutomationOn : Rez.Drawables.AutomationOff);
                break;
            case Hass.ENTITY_TYPE_BINARY_SENSOR:
                drawable = Ui.loadResource(state.equals(Hass.STATE_ON) ? Rez.Drawables.CheckboxOn : Rez.Drawables.CheckboxOff);
                break;
            case Hass.ENTITY_TYPE_INPUT_BOOLEAN:
                drawable = Ui.loadResource(state.equals(Hass.STATE_ON) ? Rez.Drawables.CheckboxOn : Rez.Drawables.CheckboxOff);
                break;
            case Hass.ENTITY_TYPE_LIGHT:
                drawable = Ui.loadResource(state.equals(Hass.STATE_ON) ? Rez.Drawables.LightOn : Rez.Drawables.LightOff);
                break;
            case Hass.ENTITY_TYPE_LOCK:
                drawable = Ui.loadResource(state.equals(Hass.STATE_LOCKED) ? Rez.Drawables.LockLocked : Rez.Drawables.LockUnlocked);
                break;
            case Hass.ENTITY_TYPE_SCENE:
                drawable = Ui.loadResource(Rez.Drawables.Scene);
                break;
            case Hass.ENTITY_TYPE_SCRIPT:
                drawable = Ui.loadResource(Rez.Drawables.ScriptOff);
                break;
            case Hass.ENTITY_TYPE_SWITCH:
                drawable = Ui.loadResource(state.equals(Hass.STATE_ON) ? Rez.Drawables.SwitchOn : Rez.Drawables.SwitchOff);
                break;
            default:
                drawable = Ui.loadResource(Rez.Drawables.Unknown);
        }
        
        dc.drawBitmap(cvw - (drawable.getHeight() / 2), (vh * 0.3) - (drawable.getHeight() / 2), drawable);
    }

    /**
    * Common draw text function
    */
    function _drawText(dc, text, hP, fonts) {
        var vh = dc.getHeight();
        var vw = dc.getWidth();
        var cvh = vh / 2;
        var cvw = vw / 2;
        var fontHeight = vh * 0.3;
        var fontWidth = vw * 0.80;
        var font = fonts[0];

        for (var i = 0; i < fonts.size(); i++) {
            var truncate = i == fonts.size() - 1;
            var tempText = Graphics.fitTextToArea(text, fonts[i], fontWidth, fontHeight, truncate);

            if (tempText != null) {
                text = tempText;
                font = fonts[i];
                break;
            }
        }

        dc.drawText(cvw, cvh * hP, font, text, Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    /**
    * Draws entity state instead of icon
    */
    function drawEntityState(dc, text) {
        _drawText(dc, text, 0.5, [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_TINY]);
    }

    /**
    * Draws entity name
    */
    function drawEntityName(dc, text) {
        _drawText(dc, text, 1.1, [Graphics.FONT_MEDIUM, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
    }

    /**
    * Draws no entity icon and text
    */
    function drawNoEntityIconText(dc) {
        var vh = dc.getHeight();
        var vw = dc.getWidth();
        var cvh = vh / 2;
        var cvw = vw / 2;
        var smileySad = Ui.loadResource(Rez.Drawables.SmileySad);

        dc.drawBitmap(cvw - (smileySad.getHeight() / 2), (vh * 0.3) - (smileySad.getHeight() / 2), smileySad);

        var font = Graphics.FONT_MEDIUM;
        var text = Ui.loadResource(Rez.Strings.NoEntities);
        text = Graphics.fitTextToArea(text, font, vw * 0.9, vh * 0.9, true);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(cvw, cvh, font, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    /**
    * Draws scroll bar
    * Supports round and square display
    */
    function drawScrollBar(dc) {
        var vh = dc.getHeight();
        var padding = 1;
        if (System.getDeviceSettings().screenShape == 3 /*SCREEN_SHAPE_RECTANGLE*/) {
            var barSize = ((vh * 0.9 - padding) - (vh * 0.1 - padding)) / _mController.getCount();
            var barStart = (vh * 0.1) + (barSize * _mController.getIndex());
            
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.setPenWidth(10);
            dc.drawLine(10, vh * 0.1, 10, vh * 0.9);

            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.setPenWidth(6);
            dc.drawLine(10, barStart, 10, barStart + barSize);
        } else { /* ROUND AND SEMIROUND */
            var cvh = vh / 2;
            var cvw = dc.getWidth() / 2;
            var radius = cvh - 10;
            var topDegreeStart = 130;
            var bottomDegreeEnd = 230;
            var barSize = ((bottomDegreeEnd - padding) - (topDegreeStart + padding)) / _mController.getCount();
            var barStart = (topDegreeStart + padding) + (barSize * _mController.getIndex());
            var attr = Graphics.ARC_COUNTER_CLOCKWISE;

            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.setPenWidth(10);
            dc.drawArc(cvw, cvh, radius, attr, topDegreeStart, bottomDegreeEnd);

            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.setPenWidth(6);
            dc.drawArc(cvw, cvh, radius, attr, barStart, barStart + barSize);
        }
    }

    /**
    * Hides scroll bar when timer expires
    */
    function onTimerDone() {
        _mTimerScrollBarActive = false;
        _mShowScrollBar = false;
        Ui.requestUpdate();
    }

    /**
    * Checks if scroll bar should be showed and draws it
    */
    function drawScrollBarIfNeeded(dc) {
        var index = _mController.getIndex();

        if (_mTimerScrollBarActive && _mShowScrollBar == true) {
            return;
        }

        if (_mLastIndex != index) {
            if (_mTimerScrollBarActive) {
                _mTimerScrollBar.stop();
            }
            _mShowScrollBar = true;
            drawScrollBar(dc);
            _mTimerScrollBar.start(method(:onTimerDone), 1000, false);
        }

        _mLastIndex = index;
    }

    function onUpdate(dc) {    
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        
        var entity = _mController.getCurrentEntityAttributes();
        var entityType = _mController.getCurrentEntityType();
        
        if (entity == null) {
            drawNoEntityIconText(dc);
            return;
        }
    
        if (entityType.equals("sensor")) {
            drawEntityState(dc, entity["state"] + " " + entity["attributes"]["unit_of_measurement"]);
        } else {
            drawEntityIcon(dc, entity["state"], entityType);
        }
        drawEntityName(dc, entity["attributes"]["friendly_name"]);
        drawScrollBarIfNeeded(dc);
    }
}