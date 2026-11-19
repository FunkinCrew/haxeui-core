package haxe.ui.backend;

import haxe.ui.Toolkit;
import haxe.ui.components.Button;
import haxe.ui.containers.Box;
import haxe.ui.containers.dialogs.Dialog;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.dragdrop.DragManager;
import haxe.ui.events.DragEvent;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.extensions.Draggable;

@:dox(hide) @:noCompletion
class DialogBase extends Box implements Draggable {
    public var modal:Bool = true;
    public var autoCenterDialog:Bool = true;
    public var buttons:DialogButton = null;
    public var centerDialog:Bool = true;
    public var button:DialogButton = null;
    public var defaultButton:String = null;

    private var _overlay:Component;

    public var dialogContainer:haxe.ui.containers.VBox;
    public var dialogTitle:haxe.ui.containers.HBox;
    public var dialogTitleLabel:haxe.ui.components.Label;
    public var dialogCloseButton:haxe.ui.components.Image;
    public var dialogContent:haxe.ui.containers.VBox;
    public var dialogFooterContainer:haxe.ui.containers.Box;
    public var dialogFooter:haxe.ui.containers.HBox;

    public function new() {
        super();

        // dialogs start off "hidden" until they are shown
        _hidden = true;

        dialogContainer = new haxe.ui.containers.VBox();
        dialogContainer.id = "dialog-container";
        dialogContainer.styleNames = "dialog-container";
        addComponent(dialogContainer);

        dialogTitle = new haxe.ui.containers.HBox();
        dialogTitle.id = "dialog-title";
        dialogTitle.styleNames = "dialog-title";
        dragInitiator = dialogTitle;
        dialogContainer.addComponent(dialogTitle);

        dialogTitleLabel = new haxe.ui.components.Label();
        dialogTitleLabel.id = "dialog-title-label";
        dialogTitleLabel.styleNames = "dialog-title-label";
        dialogTitleLabel.text = "HaxeUI";
        dialogTitle.addComponent(dialogTitleLabel);

        dialogCloseButton = new haxe.ui.components.Image();
        dialogCloseButton.id = "dialog-close-button";
        dialogCloseButton.styleNames = "dialog-close-button";
        dialogTitle.addComponent(dialogCloseButton);

        dialogContent = new haxe.ui.containers.VBox();
        dialogContent.id = "dialog-content";
        dialogContent.styleNames = "dialog-content";
        dialogContent.registerEvent(UIEvent.RESIZE, onContentResize);
        dialogContainer.addComponent(dialogContent);

        dialogFooterContainer = new haxe.ui.containers.Box();
        dialogFooterContainer.id = "dialog-footer-container";
        dialogFooterContainer.styleNames = "dialog-footer-container";
        dialogContainer.addComponent(dialogFooterContainer);

        dialogFooter = new haxe.ui.containers.HBox();
        dialogFooter.id = "dialog-footer";
        dialogFooter.styleNames = "dialog-footer";
        dialogFooter.registerEvent(UIEvent.RESIZE, onFooterResize);
        dialogFooterContainer.addComponent(dialogFooter);

        dialogFooterContainer.hide();
        dialogCloseButton.onClick = function(e) {
            hideDialog(DialogButton.CANCEL);
        }
        dialogCloseButton.registerEvent(MouseEvent.MOUSE_DOWN, cancelTitleButtonEvent);

        registerEvent(UIEvent.SUBMIT, onSubmit);
        registerEvent(DragEvent.DRAG, onDialogDrag);
        registerEvent(MouseEvent.MOUSE_DOWN, onResizeMouseDown);
    }

    private var _destroyOnClose:Bool = true;
    public var destroyOnClose(get, set):Bool;
    private function get_destroyOnClose():Bool {
        return _destroyOnClose;
    }
    private function set_destroyOnClose(value:Bool) {
        _destroyOnClose = value;
        _allowDispose = value;
        return value;
    }

    private function onSubmit(event:UIEvent) {
        if (defaultButton != null) {
            hideDialog(defaultButton);
        }
    }

    private var _autoSizeDialog:Bool = false;
    private override function onReady() {
        super.onReady();
        _autoSizeDialog = this.autoWidth;
    }

    private var _dialogParent:Component = null;
    public var dialogParent(get, set):Component;
    private function get_dialogParent():Component {
        return _dialogParent;
    }
    private function set_dialogParent(value:Component):Component {
        _dialogParent = value;
        return value;
    }

    private function cancelTitleButtonEvent(e:MouseEvent) {
        e.cancel();
    }

    /**
     * How much of the dialog, in pixels, must stay on screen horizontally while dragging.
     */
    public var dragKeepVisible:Float = 64;

    private function onDialogDrag(e:DragEvent) {
        var sx:Float = (parentComponent == null) ? Toolkit.scaleX : 1;
        var sy:Float = (parentComponent == null) ? Toolkit.scaleY : 1;
        var areaWidth:Float;
        var areaHeight:Float;
        if (parentComponent == null) {
            areaWidth = Screen.instance.actualWidth * Toolkit.scaleX;
            areaHeight = Screen.instance.actualHeight * Toolkit.scaleY;
        } else {
            areaWidth = parentComponent.width;
            areaHeight = parentComponent.height;
        }
        var w:Float = this.width * sx;
        var keep:Float = Math.min(dragKeepVisible * sx, w);
        var titleHeight:Float = Math.max(dialogTitle.height, 1) * sy;
        e.left = Math.max(keep - w, Math.min(e.left, areaWidth - keep));
        e.top = Math.max(0, Math.min(e.top, areaHeight - titleHeight));
    }

    /**
     * Lets the user resize the dialog by dragging its edges and corners.
     */
    public var resizable(default, set):Bool = false;
    private function set_resizable(value:Bool):Bool {
        resizable = value;
        if (!value) {
            setResizeEdges(false, false, false, false);
        }
        return value;
    }

    public var minResizeWidth:Null<Float> = null;
    public var minResizeHeight:Null<Float> = null;
    public var maxResizeWidth:Null<Float> = null;
    public var maxResizeHeight:Null<Float> = null;

    /**
     * The width of the grab area along each edge, in pixels.
     */
    public var resizeTolerance:Float = 8;

    private var _baseResizeWidth:Null<Float> = null;
    private var _baseResizeHeight:Null<Float> = null;

    private var _resizeN:Bool = false;
    private var _resizeE:Bool = false;
    private var _resizeS:Bool = false;
    private var _resizeW:Bool = false;
    private var _resizing:Bool = false;

    /**
     * Whether the user is dragging one of the dialog's edges right now.
     */
    public var isResizing(get, never):Bool;
    private function get_isResizing():Bool {
        return _resizing;
    }
    private var _resizeSuspendedDrag:Bool = false;
    private var _resizeLastX:Float = 0;
    private var _resizeLastY:Float = 0;

    private function canResizeVertically():Bool {
        return !dialogContent.hidden;
    }

    private function onResizeHover(e:MouseEvent) {
        if (_resizing) {
            return;
        }
        if (!resizable || _hidden || e.buttonDown || DragManager.instance.isDragging) {
            setResizeEdges(false, false, false, false);
            return;
        }
        var mx:Float = e.screenX * Toolkit.scaleX - screenLeft;
        var my:Float = e.screenY * Toolkit.scaleY - screenTop;
        var w:Float = this.width * Toolkit.scaleX;
        var h:Float = this.height * Toolkit.scaleY;
        var t:Float = resizeTolerance * Toolkit.scale;
        if (mx < 0 || my < 0 || mx > w || my > h || !isTopmostAt(e.screenX, e.screenY)) {
            setResizeEdges(false, false, false, false);
            return;
        }
        var vertical:Bool = canResizeVertically();
        setResizeEdges(vertical && my <= t, mx >= w - t, vertical && my >= h - t, mx <= t);
    }

    private function isTopmostAt(x:Float, y:Float):Bool {
        var under = Screen.instance.findComponentsUnderPoint(x, y);
        var i:Int = under.length - 1;
        while (i >= 0) {
            var c:Component = under[i];
            i--;
            if (c.style != null && c.style.pointerEvents == "none") {
                continue;
            }
            if (isInsideHidden(c)) {
                continue;
            }
            while (c != null) {
                if (c == this) {
                    return true;
                }
                c = c.parentComponent;
            }
            return false;
        }
        return false;
    }

    private function isInsideHidden(c:Component):Bool {
        while (c != null) {
            if (c.hidden) {
                return true;
            }
            c = c.parentComponent;
        }
        return false;
    }

    private function setResizeEdges(n:Bool, e:Bool, s:Bool, w:Bool) {
        if (_resizeN == n && _resizeE == e && _resizeS == s && _resizeW == w) {
            return;
        }
        _resizeN = n;
        _resizeE = e;
        _resizeS = s;
        _resizeW = w;

        var cursor:String = null;
        if ((n && w) || (s && e)) {
            cursor = "nwse-resize";
        } else if ((n && e) || (s && w)) {
            cursor = "nesw-resize";
        } else if (n || s) {
            cursor = "ns-resize";
        } else if (e || w) {
            cursor = "ew-resize";
        }
        customStyle.cursor = cursor;
        dialogTitle.customStyle.cursor = cursor;
        invalidateComponentStyle();
        dialogTitle.invalidateComponentStyle();

        // The title bar would start a move instead of a resize, so we need to temporarily disable dragging while resizing.
        if (cursor != null && draggable) {
            _resizeSuspendedDrag = true;
            draggable = false;
        } else if (cursor == null && _resizeSuspendedDrag) {
            _resizeSuspendedDrag = false;
            draggable = true;
        }
    }

    private function onResizeMouseDown(e:MouseEvent) {
        if (!resizable || _resizing || !(_resizeN || _resizeE || _resizeS || _resizeW)) {
            return;
        }
        e.cancel();
        _resizing = true;
        _resizeLastX = e.screenX;
        _resizeLastY = e.screenY;
        autoCenterDialog = false;
        _autoSizeDialog = false;
        if (_baseResizeWidth == null) {
            _baseResizeWidth = this.width;
            _baseResizeHeight = this.height;
        }
        if (autoWidth) {
            this.width = this.width;
        }
        if (autoHeight) {
            this.height = this.height;
            dialogContainer.percentHeight = 100;
            dialogContent.percentHeight = 100;
        }
        _resizeLeft = _resizeStartLeft = this.left;
        _resizeTop = _resizeStartTop = this.top;
        _resizeWidth = _resizeStartWidth = this.width;
        _resizeHeight = _resizeStartHeight = this.height;
        showResizeOutline();
        Screen.instance.registerEvent(MouseEvent.MOUSE_MOVE, onResizeDrag);
        Screen.instance.registerEvent(MouseEvent.MOUSE_UP, onResizeEnd);
    }

    private function onResizeDrag(e:MouseEvent) {
        var dx:Float = e.screenX - _resizeLastX;
        var dy:Float = e.screenY - _resizeLastY;
        var sx:Float = (parentComponent == null) ? Toolkit.scaleX : 1;
        var sy:Float = (parentComponent == null) ? Toolkit.scaleY : 1;
        var areaWidth:Float = (parentComponent == null) ? Screen.instance.actualWidth : parentComponent.width;
        var areaHeight:Float = (parentComponent == null) ? Screen.instance.actualHeight : parentComponent.height;
        var minW:Float = Math.max(minResizeWidth != null ? minResizeWidth : Math.min(_baseResizeWidth, Math.max(_baseResizeWidth * 0.6, 160)), 1);
        var minH:Float = Math.max(minResizeHeight != null ? minResizeHeight : Math.min(_baseResizeHeight, Math.max(_baseResizeHeight * 0.5, 120)), 1);
        var maxW:Float = Math.max(Math.min(maxResizeWidth != null ? maxResizeWidth : areaWidth, areaWidth), minW);
        var maxH:Float = Math.max(Math.min(maxResizeHeight != null ? maxResizeHeight : areaHeight, areaHeight), minH);

        var horizontal:Bool = _resizeE || _resizeW;
        var vertical:Bool = _resizeN || _resizeS;
        var w:Float = _resizeStartWidth + (_resizeE ? dx : (_resizeW ? -dx : 0));
        var h:Float = _resizeStartHeight + (_resizeS ? dy : (_resizeN ? -dy : 0));

        // CTRL key is a shortcut to keep the aspect ratio while resizing (if not disabled by keepAspectRatio)
        if ((keepAspectRatio || e.ctrlKey) && canResizeVertically() && _resizeStartHeight > 0) {
            var ratio:Float = _resizeStartWidth / _resizeStartHeight;
            // Keep the aspect ratio, but don't let the dialog shrink below its minimum size.
            if (horizontal && (!vertical || w / _resizeStartWidth >= h / _resizeStartHeight)) {
                h = w / ratio;
            } else {
                w = h * ratio;
            }
            if (w < minW) { w = minW; h = w / ratio; }
            if (h < minH) { h = minH; w = h * ratio; }
            if (w > maxW) { w = maxW; h = w / ratio; }
            if (h > maxH) { h = maxH; w = h * ratio; }
        } else {
            if (horizontal) {
                w = Math.min(Math.max(w, minW), maxW);
            }
            if (vertical) {
                h = Math.min(Math.max(h, minH), maxH);
            }
        }

        _resizeWidth = w;
        _resizeHeight = h;
        _resizeLeft = _resizeW ? _resizeStartLeft + (_resizeStartWidth - w) * sx : _resizeStartLeft;
        _resizeTop = _resizeN ? _resizeStartTop + (_resizeStartHeight - h) * sy : _resizeStartTop;
        updateResizeOutline();
    }

    /**
     * If true, the dialog will maintain its aspect ratio while resizing.
     */
    public var keepAspectRatio:Bool = false;

    private var _resizeStartLeft:Float = 0;
    private var _resizeStartTop:Float = 0;
    private var _resizeStartWidth:Float = 0;
    private var _resizeStartHeight:Float = 0;

    private var _resizeLeft:Float = 0;
    private var _resizeTop:Float = 0;
    private var _resizeWidth:Float = 0;
    private var _resizeHeight:Float = 0;
    private var _resizeOutline:Component = null;

    private function showResizeOutline() {
        if (_resizeOutline == null) {
            _resizeOutline = new Component();
            _resizeOutline.id = "dialog-resize-outline";
            _resizeOutline.addClass("dialog-resize-outline");
            _resizeOutline.includeInLayout = false;
        }
        _resizeOutline.customStyle.cursor = customStyle.cursor;
        _resizeOutline.invalidateComponentStyle();
        if (parentComponent != null) {
            parentComponent.addComponent(_resizeOutline);
        } else {
            Screen.instance.addComponent(_resizeOutline);
        }
        updateResizeOutline();
    }

    private function updateResizeOutline() {
        if (_resizeOutline == null) {
            return;
        }
        _resizeOutline.width = _resizeWidth;
        _resizeOutline.height = _resizeHeight;
        _resizeOutline.moveComponent(_resizeLeft, _resizeTop);
    }

    private function hideResizeOutline() {
        if (_resizeOutline == null || _resizeOutline.parentComponent == null && !Screen.instance.rootComponents.contains(_resizeOutline)) {
            return;
        }
        if (_resizeOutline.parentComponent != null) {
            _resizeOutline.parentComponent.removeComponent(_resizeOutline, false);
        } else {
            Screen.instance.removeComponent(_resizeOutline, false);
        }
    }

    private function onResizeEnd(e:MouseEvent) {
        stopResizing();
    }

    private function stopResizing() {
        Screen.instance.unregisterEvent(MouseEvent.MOUSE_MOVE, onResizeDrag);
        Screen.instance.unregisterEvent(MouseEvent.MOUSE_UP, onResizeEnd);
        if (_resizing) {
            hideResizeOutline();
            this.width = _resizeWidth;
            this.height = _resizeHeight;
            this.left = _resizeLeft;
            this.top = _resizeTop;
        }
        _resizing = false;
        setResizeEdges(false, false, false, false);
    }

    public function showDialog(modal:Bool = true) {
        this.modal = modal;
        show();
    }

    private var _forcedLeft:Null<Float> = null;
    private override function set_left(value:Null<Float>):Null<Float> {
        super.set_left(value);
        autoCenterDialog = false;
        _forcedLeft = value;
        return value;
    }

    private var _forcedTop:Null<Float> = null;
    private override function set_top(value:Null<Float>):Null<Float> {
        super.set_top(value);
        autoCenterDialog = false;
        _forcedTop = value;
        return value;
    }

    public override function show() {
        #if !haxeui_flixel
        handleVisibility(false);
        #end
        super.show();
        var dp = dialogParent;
        if (modal) {
            if (_overlay == null) {
                _overlay = new Component();
                _overlay.id = "modal-background";
                _overlay.addClass("modal-background");
                _overlay.percentWidth = _overlay.percentHeight = 100;
                _overlay.onClick = function(_) {
                    if (closable) {
                        hideDialog(DialogButton.CANCEL);
                    }
                }
            }

            if (dp != null) {
                includeInLayout = false;
        		_overlay.includeInLayout = false;
        		_overlay.height = dp.height;
        		_overlay.width = dp.width;
        		dp.addComponent(_overlay);
            } else {
                Screen.instance.addComponent(_overlay);
            }
        }
        createButtons();

        if (dp != null) {
            dp.addComponent(this);
        } else {
            Screen.instance.addComponent(this);
        }
        Screen.instance.unregisterEvent(MouseEvent.MOUSE_MOVE, onResizeHover);
        Screen.instance.registerEvent(MouseEvent.MOUSE_MOVE, onResizeHover);
        this.syncComponentValidation();
        if (autoHeight == false) {
            dialogContainer.percentHeight = 100;
            dialogContent.percentHeight = 100;
        }
        if (centerDialog) {
            centerDialogComponent(cast(this, Dialog));
        }

        Toolkit.callLater(function() {
            if (centerDialog) {
                centerDialogComponent(cast(this, Dialog));
            }
            Toolkit.callLater(function() {
                handleVisibility(true);
                if (centerDialog) {
                    centerDialogComponent(cast(this, Dialog));
                }
                _forcedLeft = null;
                _forcedTop = null;
                if (dp != null) {
                    dp.registerEvent(UIEvent.RESIZE, _onParentResized);
                } else {
                    Screen.instance.registerEvent(UIEvent.RESIZE, _onScreenResized);
                }
            });
        });
    }

    private function _onScreenResized(_) {
        if (!autoCenterDialog) {
            return;
        }

        _forcedLeft = null;
        _forcedTop = null;
        centerDialogComponent(cast this);
    }

    private function _onParentResized(_) {
        if (_overlay != null) {
            _overlay.width = dialogParent.width;
            _overlay.height = dialogParent.height;
        }

        if (!autoCenterDialog) {
            return;
        }

        _forcedLeft = null;
        _forcedTop = null;
        centerDialogComponent(cast this, false);
    }

    private var _buttonsCreated:Bool = false;
    private function createButtons() {
        if (_buttonsCreated == true) {
            return;
        }
        if (buttons != null) {
            for (button in buttons.toArray()) {
                var buttonComponent = new Button();
                buttonComponent.id = button.toString().toLowerCase();
                var text = button.toString();
                buttonComponent.text = text;
                buttonComponent.userData = button;
                buttonComponent.registerEvent(MouseEvent.CLICK, onFooterButtonClick);
                if (defaultButton != null && buttonComponent.text == defaultButton) {
                    buttonComponent.addClass("emphasized");
                }
                addFooterComponent(buttonComponent);
            }
            _buttonsCreated = true;
        }
    }

    public var closable(get, set):Bool;
    private function get_closable():Bool {
        return !dialogCloseButton.hidden;
    }
    private function set_closable(value:Bool):Bool {
        if (value == true) {
            dialogCloseButton.show();
        } else {
            dialogCloseButton.hide();
        }
        return value;
    }

    private function validateDialog(button:DialogButton, fn:Bool->Void) {
        fn(true);
    }

    public override function hide() {
        validateDialog(this.button, function(result) {
            if (result == true) {
                var dp = dialogParent;

                var event = new DialogEvent(DialogEvent.DIALOG_CLOSED);
                event.button = this.button;
                dispatch(event);
                if (event.canceled == true) {
                    return;
                }

                _hidden = true;
                Screen.instance.unregisterEvent(MouseEvent.MOUSE_MOVE, onResizeHover);
                if (_resizing) {
                    stopResizing();
                }
                if (modal && _overlay != null) {
                    if (dp != null) {
                        dp.removeComponent(_overlay, destroyOnClose);
                    } else {
                        Screen.instance.removeComponent(_overlay, destroyOnClose);
                    }
                }
                if (dp != null) {
                    dp.removeComponent(this, destroyOnClose);
                } else {
                    Screen.instance.removeComponent(this, destroyOnClose);
                }
            }
        });
    }

    public function hideDialog(button:DialogButton) {
        this.button = button;
        hide();
    }

    public var title(get, set):String;
    private function get_title():String {
        return dialogTitleLabel.text;
    }
    private function set_title(value:String):String {
        dialogTitleLabel.text = value;
        return value;
    }

    public override function addComponent(child:Component):Component {
        if (child == dialogContainer) {
            return super.addComponent(child);
        }
        return dialogContent.addComponent(child);
    }

    public override function validateComponentLayout():Bool {
        var b = super.validateComponentLayout();
        dialogTitle.width = this.layout.innerWidth;
        if (_autoSizeDialog == false) {
            var offset = this.layout.paddingLeft + this.layout.paddingRight;
            if (dialogContent.width != this.width - offset) {
                dialogContent.width = this.width - offset;
            }
            if (dialogFooterContainer.width != this.width - offset) {
                dialogFooterContainer.width = this.width - offset;
            }
        }

        return b;
    }

    private override function onDestroy() {
        super.onDestroy();
        Screen.instance.unregisterEvent(MouseEvent.MOUSE_MOVE, onResizeHover);
        Screen.instance.unregisterEvent(MouseEvent.MOUSE_MOVE, onResizeDrag);
        Screen.instance.unregisterEvent(MouseEvent.MOUSE_UP, onResizeEnd);
        if (_resizeOutline != null) {
            hideResizeOutline();
            _resizeOutline.disposeComponent();
            _resizeOutline = null;
        }
        if (_overlay != null) {
            if (dialogParent != null) {
                dialogParent.removeComponent(_overlay);
            } else {
                Screen.instance.removeComponent(_overlay);
            }
            _overlay = null;
        }
        if (dialogParent != null) {
            dialogParent.unregisterEvent(UIEvent.RESIZE, _onParentResized);
        } else {
            Screen.instance.unregisterEvent(UIEvent.RESIZE, _onScreenResized);
        }
    }

    private function onContentResize(e) {
        if (dialogFooter.width <= 0 || dialogFooterContainer.width <= 0 || _autoSizeDialog == false) {
            return;
        }

        var cx = Math.max(dialogFooter.width, dialogContent.width);
        var offset = this.layout.paddingLeft + this.layout.paddingRight;
        var recenter:Bool = false;

        if (cx > 0 && cx != this.width + offset) {
            this.width = cx + offset;
            recenter = true;
        }

        if (dialogFooterContainer.width != this.width - offset) {
            dialogFooterContainer.width = this.width - offset;
        }

        if (recenter == true && autoCenterDialog == true) {
            centerDialogComponent(cast(this, Dialog), false);
        }
    }

    private function onFooterResize(e) {
        if (dialogFooter.width <= 0 || dialogFooterContainer.width <= 0 || _autoSizeDialog == false) {
            return;
        }
        var cx = Math.max(dialogFooter.width, dialogContent.width);
        var offset = this.layout.paddingLeft + this.layout.paddingRight;
        var recenter:Bool = false;

        if (cx > 0 && cx != this.width + offset) {
            this.width = cx + offset;
            recenter = true;
        }

        if (dialogFooterContainer.width != this.width - offset) {
            dialogFooterContainer.width = this.width - offset;
        }

        if (recenter == true && autoCenterDialog == true) {
            centerDialogComponent(cast(this, Dialog), false);
        }
    }

    public function addFooterComponent(c:Component) {
        dialogFooterContainer.show();
        dialogFooter.addComponent(c);
    }

    public function centerDialogComponent(dialog:Dialog, validate:Bool = true) {
        if (_isDisposed) {
            return;
        }

        if (validate == true) {
            dialog.syncComponentValidation();
        }
        var dp = dialogParent;
        if (dp != null) {
            if (validate == true) {
                dp.syncComponentValidation();
            }
            var x = (dp.actualComponentWidth / 2) - (dialog.actualComponentWidth / 2);
            if (_forcedLeft != null && _forcedLeft > 0) {
                x = _forcedLeft;
            }
            var y = (dp.actualComponentHeight / 2) - (dialog.actualComponentHeight / 2);
            if (_forcedTop != null && _forcedTop > 0) {
                y = _forcedTop;
            }
            dialog.moveComponent(x, y);
        } else {
            var x = (Screen.instance.actualWidth / 2) - (dialog.actualComponentWidth / 2);
            if (_forcedLeft != null && _forcedLeft > 0) {
                x = _forcedLeft;
            }
            var y = (Screen.instance.actualHeight / 2) - (dialog.actualComponentHeight / 2);
            if (_forcedTop != null && _forcedTop > 0) {
                y = _forcedTop;
            }
            dialog.moveComponent(x, y);
        }
    }

    private function onFooterButtonClick(event:MouseEvent) {
        hideDialog(event.target.userData);
    }
}
